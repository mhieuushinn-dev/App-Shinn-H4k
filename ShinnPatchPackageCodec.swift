import CommonCrypto
import CryptoKit
import Foundation
import Security

// MARK: - Kết quả decode
struct ShinnDecodedPatch {
    let packageID: UUID
    let bundleID: String
    let contentKey: Data
    let project: ShinnPatchProject
}

struct ShinnEncodedPatch {
    let data: Data
    let contentKey: Data
}

// MARK: - Lỗi
enum ShinnPatchError: Error, Equatable {
    case unsupportedFormat
    case unsupportedVersion
    case wrongPassword
    case corrupted
    case invalidProject
    case invalidBundle
    case unsafePath
    case sizeLimit
    case duplicateTarget
    case keychainFailed
    case targetAppUnavailable(String)
    case applyFailed
    case restoreFailed
    case restoreChanged([String])
    case alreadyApplied
    case activeCannotDelete

    var localizationKey: String {
        switch self {
        case .unsupportedFormat: return "patch.error.unsupported_format"
        case .unsupportedVersion: return "patch.error.unsupported_version"
        case .wrongPassword: return "patch.error.wrong_password"
        case .corrupted: return "patch.error.corrupted"
        case .invalidProject: return "patch.error.invalid_project"
        case .invalidBundle: return "patch.error.invalid_bundle"
        case .unsafePath: return "patch.error.unsafe_path"
        case .sizeLimit: return "patch.error.size_limit"
        case .duplicateTarget: return "patch.error.duplicate_target"
        case .keychainFailed: return "patch.error.keychain"
        case .targetAppUnavailable: return "patch.error.app_unavailable"
        case .applyFailed: return "patch.error.apply"
        case .restoreFailed: return "patch.error.restore"
        case .restoreChanged: return "patch.error.restore_changed"
        case .alreadyApplied: return "patch.error.already_applied"
        case .activeCannotDelete: return "patch.error.active_delete"
        }
    }
}

// MARK: - Codec
enum ShinnPatchPackageCodec {
    private static let magic = Data("3105PATCH\0".utf8)
    private static let minimumSchema = 1
    private static let maximumSchema = 3

    private struct Envelope: Codable {
        let schemaVersion: Int
        let keyAADVersion: Int?
        let packageID: UUID
        let isPasswordProtected: Bool
        let kdfSalt: Data?
        let kdfIterations: Int?
        let wrappedContentKey: Data?
        let publicContentKey: Data?
        let keyFingerprint: Data
        let encryptedPayload: Data
    }

    private struct Payload: Codable {
        let project: ShinnPatchProjectPayload
        let replacementDigests: [String: Data]
    }

    private struct ShinnPatchProjectPayload: Codable {
        let id: UUID
        let name: String
        let author: String
        let isPrivate: Bool
        let createdAt: Date
        let updatedAt: Date
        let bundleIdentifiers: [String]
        let rules: [ShinnPatchRulePayload]
    }

    private struct ShinnPatchRulePayload: Codable {
        let id: UUID
        let bundleID: String
        let relativePath: String
        let replacementFilename: String
        let replacementData: Data
    }

    // MARK: - Inspect
    static func inspect(_ data: Data) throws -> ShinnPatchSummary {
        let env = try parse(data)
        let bundleID = try extractBundleID(from: env, data: data) ?? "unknown"
        return ShinnPatchSummary(
            packageID: env.packageID,
            schemaVersion: env.schemaVersion,
            isPasswordProtected: env.isPasswordProtected,
            keyFingerprint: env.keyFingerprint,
            bundleID: bundleID
        )
    }

    // MARK: - Decode with password
    static func decode(_ data: Data, password: String?) throws -> ShinnDecodedPatch {
        let env = try parse(data)
        let contentKey: Data
        if env.isPasswordProtected {
            guard let password, !password.isEmpty,
                  let salt = env.kdfSalt,
                  let iterations = env.kdfIterations,
                  let wrapped = env.wrappedContentKey else {
                throw ShinnPatchError.wrongPassword
            }
            let wrappingKey = try deriveKey(
                password: password,
                salt: salt,
                iterations: iterations
            )
            contentKey = try open(
                wrapped,
                key: wrappingKey,
                aad: keyAAD(for: env.packageID, version: env.keyAADVersion ?? env.schemaVersion)
            )
        } else {
            guard let storedKey = env.publicContentKey else {
                throw ShinnPatchError.corrupted
            }
            contentKey = storedKey
        }
        return try decode(env: env, contentKey: contentKey)
    }

    // MARK: - Decode with content key
    static func decode(_ data: Data, contentKey: Data) throws -> ShinnDecodedPatch {
        let env = try parse(data)
        return try decode(env: env, contentKey: contentKey)
    }

    // MARK: - Internal
    private static func decode(env: Envelope, contentKey: Data) throws -> ShinnDecodedPatch {
        guard contentKey.count == 32,
              Data(SHA256.hash(data: contentKey)) == env.keyFingerprint else {
            throw ShinnPatchError.corrupted
        }
        let payloadData = try open(
            env.encryptedPayload,
            key: contentKey,
            aad: payloadAAD(for: env.packageID, version: env.schemaVersion)
        )
        let payload = try PropertyListDecoder().decode(Payload.self, from: payloadData)

        guard payload.project.id == env.packageID else {
            throw ShinnPatchError.corrupted
        }
        guard let firstBundleID = payload.project.bundleIdentifiers.first else {
            throw ShinnPatchError.invalidBundle
        }

        for rule in payload.project.rules {
            let actual = Data(SHA256.hash(data: rule.replacementData))
            guard payload.replacementDigests[rule.id.uuidString] == actual else {
                throw ShinnPatchError.corrupted
            }
        }

        let project = ShinnPatchProject(
            id: payload.project.id,
            name: payload.project.name,
            author: payload.project.author,
            isPrivate: payload.project.isPrivate,
            bundleIdentifiers: payload.project.bundleIdentifiers,
            rules: payload.project.rules.map {
                ShinnPatchRule(
                    id: $0.id,
                    bundleID: $0.bundleID,
                    relativePath: $0.relativePath,
                    replacementFilename: $0.replacementFilename,
                    replacementData: $0.replacementData
                )
            }
        )
        return ShinnDecodedPatch(
            packageID: env.packageID,
            bundleID: firstBundleID,
            contentKey: contentKey,
            project: project
        )
    }

    private static func extractBundleID(from env: Envelope, data: Data) throws -> String? {
        if !env.isPasswordProtected, let key = env.publicContentKey {
            if let decoded = try? decode(env: env, contentKey: key) {
                return decoded.bundleID
            }
        }
        return nil
    }

    // MARK: - Parsing
    private static func parse(_ data: Data) throws -> Envelope {
        guard data.count > magic.count,
              data.prefix(magic.count) == magic else {
            throw ShinnPatchError.unsupportedFormat
        }
        let body = data.dropFirst(magic.count)
        let env: Envelope
        do {
            env = try PropertyListDecoder().decode(Envelope.self, from: Data(body))
        } catch {
            throw ShinnPatchError.corrupted
        }
        guard (minimumSchema...maximumSchema).contains(env.schemaVersion) else {
            throw ShinnPatchError.unsupportedVersion
        }
        guard env.keyFingerprint.count == 32,
              env.encryptedPayload.count >= 28 else {
            throw ShinnPatchError.corrupted
        }
        if env.isPasswordProtected {
            guard env.publicContentKey == nil,
                  env.kdfSalt?.count == 16,
                  let iters = env.kdfIterations,
                  (100_000...1_000_000).contains(iters),
                  env.wrappedContentKey != nil else {
                throw ShinnPatchError.corrupted
            }
        } else {
            guard env.kdfSalt == nil,
                  env.kdfIterations == nil,
                  env.wrappedContentKey == nil,
                  env.publicContentKey?.count == 32 else {
                throw ShinnPatchError.corrupted
            }
        }
        return env
    }

    // MARK: - Crypto
    private static func seal(_ plaintext: Data, key: Data, aad: Data) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key), authenticating: aad)
        guard let combined = sealed.combined else {
            throw ShinnPatchError.corrupted
        }
        return combined
    }

    private static func open(_ ciphertext: Data, key: Data, aad: Data) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: ciphertext)
            return try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad)
        } catch {
            throw ShinnPatchError.wrongPassword
        }
    }

    private static func deriveKey(password: String, salt: Data, iterations: Int) throws -> Data {
        let passwordData = Data(password.utf8)
        var output = Data(count: 32)
        let status = output.withUnsafeMutableBytes { outBuf in
            passwordData.withUnsafeBytes { pwBuf in
                salt.withUnsafeBytes { saltBuf in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pwBuf.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBuf.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        outBuf.bindMemory(to: UInt8.self).baseAddress,
                        32
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw ShinnPatchError.corrupted }
        return output
    }

    private static func keyAAD(for id: UUID, version: Int) -> Data {
        Data("3105PATCH/v\(version)/key/\(id.uuidString)".utf8)
    }

    private static func payloadAAD(for id: UUID, version: Int) -> Data {
        Data("3105PATCH/v\(version)/payload/\(id.uuidString)".utf8)
    }
}

// MARK: - Public models
struct ShinnPatchSummary: Equatable {
    let packageID: UUID
    let schemaVersion: Int
    let isPasswordProtected: Bool
    let keyFingerprint: Data
    let bundleID: String
}

struct ShinnPatchProject: Equatable {
    let id: UUID
    let name: String
    let author: String
    let isPrivate: Bool
    let bundleIdentifiers: [String]
    let rules: [ShinnPatchRule]
}

struct ShinnPatchRule: Identifiable, Equatable {
    let id: UUID
    let bundleID: String
    let relativePath: String
    let replacementFilename: String
    let replacementData: Data
}