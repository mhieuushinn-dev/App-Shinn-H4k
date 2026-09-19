import CryptoKit
import Foundation

// MARK: - Repo Kind
enum ShinnRepositoryKind: String, Codable, CaseIterable {
    case shinnThieuu
    case shinnChest

    var manifestURL: URL {
        switch self {
        case .shinnThieuu:
            return URL(string:
                "https://raw.githubusercontent.com/mhieuushinn-dev/ShinnCheat/main/ShinnThieuu.json"
            )!
        case .shinnChest:
            return URL(string:
                "https://raw.githubusercontent.com/mhieuushinn-dev/ShinnCheat/main/Shinn%20Chest.json"
            )!
        }
    }

    var displayName: String {
        switch self {
        case .shinnThieuu: return "ShinnThieuu"
        case .shinnChest: return "Shinn Chest"
        }
    }
}

// MARK: - Source
struct ShinnRepositorySource: Identifiable, Hashable {
    let id: UUID
    let kind: ShinnRepositoryKind

    init(id: UUID = UUID(), kind: ShinnRepositoryKind) {
        self.id = id
        self.kind = kind
    }

    var manifestURL: URL { kind.manifestURL }
    var displayName: String { kind.displayName }
}

// MARK: - State
enum ShinnRepositoryState: Equatable {
    case idle
    case loading
    case loaded(Date)
    case failed(ShinnRepositoryError)
}

// MARK: - Errors
enum ShinnRepositoryError: Error, Equatable {
    case insecureURL
    case invalidManifest
    case sourceUnavailable
    case checksumMismatch
    case unsupportedSchema
    case packageTooLarge
    case importUnavailable
    case incompatiblePackage

    var localizationKey: String {
        switch self {
        case .insecureURL: return "repository.error.insecure_url"
        case .invalidManifest: return "repository.error.invalid_manifest"
        case .sourceUnavailable: return "repository.error.source_unavailable"
        case .checksumMismatch: return "repository.error.checksum"
        case .unsupportedSchema: return "repository.error.unsupported_schema"
        case .packageTooLarge: return "repository.error.package_too_large"
        case .importUnavailable: return "repository.error.import_unavailable"
        case .incompatiblePackage: return "repository.error.incompatible"
        }
    }
}

// MARK: - Manifest decode
struct ShinnRepositoryDocument: Decodable {
    let schemaVersion: Int
    let identifier: String
    let name: String
    let description: String?
    let accentColor: String?
    let icon: String?
    let packages: [ShinnPackageDocument]
}

struct ShinnPackageDocument: Decodable {
    let identifier: String
    let name: String
    let author: String
    let version: String
    let summary: String
    let description: String?
    let category: String?
    let tags: [String]?
    let publishedAt: String?
    let download: String
    let sha256: String?
    let size: UInt64?
    let supportedOS: [ShinnOSRange]?
    let featured: Bool?
    let isPrivate: Bool?
    let icon: String?
}

struct ShinnOSRange: Codable, Hashable {
    let minimum: String
    let maximum: String
    let builds: [String]?
}

// MARK: - Resolved models
struct ShinnRepositoryManifest: Equatable {
    let kind: ShinnRepositoryKind
    let identifier: String
    let name: String
    let description: String?
    let accentColor: String?
    let iconURL: URL?
    let packages: [ShinnRepositoryPackage]
    let sourceURL: URL
}

struct ShinnRepositoryPackage: Identifiable, Hashable {
    let id: String
    let repositoryKind: ShinnRepositoryKind
    let repositoryName: String
    let identifier: String
    let name: String
    let author: String
    let version: String
    let summary: String
    let details: String?
    let category: String?
    let tags: [String]
    let publishedAt: Date?
    let downloadURL: URL
    let sha256: String?
    let expectedSize: UInt64?
    let supportedOS: [ShinnOSRange]
    let isFeatured: Bool
    let isPrivate: Bool
    let iconURL: URL?

    static func == (lhs: ShinnRepositoryPackage, rhs: ShinnRepositoryPackage) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Validator
enum ShinnRepositoryValidator {
    private static let maximumManifestBytes = 10 * 1_024 * 1_024
    private static let maximumPackages = 2_000

    static func validate(
        data: Data,
        kind: ShinnRepositoryKind,
        sourceURL: URL
    ) throws -> ShinnRepositoryManifest {
        guard data.count <= maximumManifestBytes else {
            throw ShinnRepositoryError.invalidManifest
        }
        let trustedURL = try validateURL(sourceURL)

        let document: ShinnRepositoryDocument
        do {
            document = try JSONDecoder().decode(ShinnRepositoryDocument.self, from: data)
        } catch {
            throw ShinnRepositoryError.invalidManifest
        }

        guard document.schemaVersion == 1 else {
            throw ShinnRepositoryError.unsupportedSchema
        }
        guard !document.identifier.isEmpty,
              !document.name.isEmpty,
              document.packages.count <= maximumPackages else {
            throw ShinnRepositoryError.invalidManifest
        }

        let iconURL = try document.icon.flatMap {
            try? resolveURL($0, relativeTo: trustedURL)
        }

        var seen = Set<String>()
        var packages: [ShinnRepositoryPackage] = []
        for pkg in document.packages {
            guard seen.insert(pkg.identifier).inserted else { continue }
            do {
                packages.append(try validatePackage(
                    pkg,
                    kind: kind,
                    repositoryName: document.name,
                    sourceURL: trustedURL
                ))
            } catch {
                log("shinnh4k: skipped invalid package \(pkg.identifier)")
                continue
            }
        }

        return ShinnRepositoryManifest(
            kind: kind,
            identifier: document.identifier,
            name: document.name,
            description: document.description,
            accentColor: document.accentColor,
            iconURL: iconURL,
            packages: packages,
            sourceURL: trustedURL
        )
    }

    private static func validatePackage(
        _ pkg: ShinnPackageDocument,
        kind: ShinnRepositoryKind,
        repositoryName: String,
        sourceURL: URL
    ) throws -> ShinnRepositoryPackage {
        guard !pkg.identifier.isEmpty,
              !pkg.name.isEmpty,
              !pkg.version.isEmpty,
              !pkg.summary.isEmpty else {
            throw ShinnRepositoryError.invalidManifest
        }

        let downloadURL = try resolveURL(pkg.download, relativeTo: sourceURL)
        let iconURL = try pkg.icon.flatMap {
            try? resolveURL($0, relativeTo: sourceURL)
        }

        if let sha = pkg.sha256 {
            guard sha.count == 64,
                  sha.unicodeScalars.allSatisfy({ scalar in
                      let v = scalar.value
                      return (48...57).contains(v)
                          || (65...70).contains(v)
                          || (97...102).contains(v)
                  }) else {
                throw ShinnRepositoryError.invalidManifest
            }
        }

        var parsedDate: Date?
        if let raw = pkg.publishedAt {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            parsedDate = iso.date(from: raw)
            if parsedDate == nil {
                iso.formatOptions = [.withInternetDateTime]
                parsedDate = iso.date(from: raw)
            }
        }

        let normalizedCategory = pkg.category?.trimmingCharacters(in: .whitespacesAndNewlines)

        return ShinnRepositoryPackage(
            id: "\(kind.rawValue)#\(pkg.identifier)",
            repositoryKind: kind,
            repositoryName: repositoryName,
            identifier: pkg.identifier,
            name: pkg.name.trimmingCharacters(in: .whitespacesAndNewlines),
            author: pkg.author.trimmingCharacters(in: .whitespacesAndNewlines),
            version: pkg.version.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: pkg.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            details: pkg.description?.trimmingCharacters(in: .whitespacesAndNewlines),
            category: (normalizedCategory?.isEmpty == false) ? normalizedCategory : nil,
            tags: pkg.tags ?? [],
            publishedAt: parsedDate,
            downloadURL: downloadURL,
            sha256: pkg.sha256?.lowercased(),
            expectedSize: pkg.size,
            supportedOS: pkg.supportedOS ?? [],
            isFeatured: pkg.featured ?? false,
            isPrivate: pkg.isPrivate ?? false,
            iconURL: iconURL
        )
    }

    static func validateURL(_ url: URL) throws -> URL {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "raw.githubusercontent.com",
              url.user == nil,
              url.password == nil else {
            throw ShinnRepositoryError.insecureURL
        }
        return url.absoluteURL
    }

    static func resolveURL(_ raw: String, relativeTo base: URL) throws -> URL {
        guard let url = URL(string: raw, relativeTo: base)?.absoluteURL else {
            throw ShinnRepositoryError.insecureURL
        }
        return try validateURL(url)
    }
}

// MARK: - Compatibility
enum ShinnPackageCompatibility: Equatable {
    case compatible
    case incompatible
    case unknown
}

enum ShinnCompatibilityEvaluator {
    static func evaluate(
        _ ranges: [ShinnOSRange],
        major: Int,
        minor: Int,
        patch: Int,
        build: String
    ) -> ShinnPackageCompatibility {
        guard !ranges.isEmpty else { return .unknown }
        for range in ranges {
            guard let min = versionTuple(range.minimum),
                  let max = versionTuple(range.maximum) else { continue }
            let current = (major, minor, patch)
            if current < min || current > max { continue }
            if let builds = range.builds, !builds.isEmpty {
                return builds.contains(build) ? .compatible : .incompatible
            }
            return .compatible
        }
        return .incompatible
    }

    private static func versionTuple(_ raw: String) -> (Int, Int, Int)? {
        let parts = raw.split(separator: ".").compactMap { Int($0) }
        guard !parts.isEmpty, parts.count <= 3 else { return nil }
        let major = parts[0]
        let minor = parts.count > 1 ? parts[1] : 0
        let patch = parts.count > 2 ? parts[2] : 0
        return (major, minor, patch)
    }
}

// MARK: - Digest helper
enum ShinnDigest {
    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Hex(fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}