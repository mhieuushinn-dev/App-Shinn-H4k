import Foundation
import Security
import CryptoKit

// MARK: - Role
enum ShinnRole: String, Codable, CaseIterable {
    case owner = "owner"
    case admin = "admin"
    case support = "support"
    case member = "member"
    case dog = "dog"

    var keyCode: String {
        switch self {
        case .owner: return "080109"
        case .admin: return "00001"
        case .support: return "00002"
        case .member: return "00003"
        case .dog: return "00000"
        }
    }

    /// Username bắt buộc — chỉ Owner và Admin mới có
    var requiredUsername: String? {
        switch self {
        case .owner: return "NgVuMinhHieuu"
        case .admin: return "10001"
        case .support, .member, .dog: return nil
        }
    }

    var requiresUsername: Bool { requiredUsername != nil }

    var displayNameVI: String {
        switch self {
        case .owner: return "Chủ sở hữu"
        case .admin: return "Admin"
        case .support: return "Support"
        case .member: return "Thành viên"
        case .dog: return "Dog"
        }
    }

    var displayNameEN: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .support: return "Support"
        case .member: return "Member"
        case .dog: return "Dog"
        }
    }

    /// Quyền xem repo Shinn Chest (repo 2)
    var canAccessShinnChest: Bool {
        switch self {
        case .owner, .admin: return true
        case .support, .member, .dog: return false
        }
    }

    /// Quyền xem repo ShinnThieuu (repo 1) — mọi role đều có
    var canAccessShinnThieuu: Bool { true }

    /// Quyền áp dụng patch — Dog bị chặn
    var canApplyPatch: Bool {
        switch self {
        case .owner, .admin, .support, .member: return true
        case .dog: return false
        }
    }

    /// Quyền tải package — Dog bị chặn
    var canDownloadPackage: Bool {
        switch self {
        case .owner, .admin, .support, .member: return true
        case .dog: return false
        }
    }

    /// Quyền xoá nguồn repo — chỉ Owner và Admin
    var canDeleteSources: Bool {
        switch self {
        case .owner, .admin: return true
        default: return false
        }
    }

    /// Quyền xoá patch đã cài — chỉ Owner và Admin
    var canDeleteInstalled: Bool {
        switch self {
        case .owner, .admin: return true
        default: return false
        }
    }
}

// MARK: - Session
struct ShinnSession: Codable, Equatable {
    let role: ShinnRole
    let username: String?
    let keyHash: Data
    let signedInAt: Date

    static func make(role: ShinnRole, username: String?, rawKey: String) -> ShinnSession {
        let hash = Data(SHA256.hash(data: Data(rawKey.utf8)))
        return ShinnSession(
            role: role,
            username: username?.trimmingCharacters(in: .whitespacesAndNewlines),
            keyHash: hash,
            signedInAt: Date()
        )
    }

    func matches(rawKey: String, username: String?) -> Bool {
        guard Data(SHA256.hash(data: Data(rawKey.utf8))) == keyHash else { return false }
        if let required = role.requiredUsername {
            let normalized = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return normalized.caseInsensitiveCompare(required) == .orderedSame
        }
        return true
    }
}

// MARK: - Auth Service
enum ShinnAuthService {
    private static let service = "com.shinnh4k.auth"
    private static let account = "active-session"

    /// Xác minh key + username → trả về role nếu hợp lệ
    static func resolveRole(rawKey: String, username: String?) -> ShinnRole? {
        let normalizedKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let role = ShinnRole.allCases.first(where: { $0.keyCode == normalizedKey }) else {
            return nil
        }
        if let required = role.requiredUsername {
            let normalizedUsername = username?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !normalizedUsername.isEmpty,
                  normalizedUsername.caseInsensitiveCompare(required) == .orderedSame else {
                return nil
            }
        }
        return role
    }

    static func persist(session: ShinnSession) throws {
        guard let data = try? JSONEncoder().encode(session) else {
            throw ShinnAuthError.keychainFailed
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw ShinnAuthError.keychainFailed
        }
        var newItem = query
        attributes.forEach { newItem[$0.key] = $0.value }
        guard SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess else {
            throw ShinnAuthError.keychainFailed
        }
    }

    static func loadSession() -> ShinnSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let session = try? JSONDecoder().decode(ShinnSession.self, from: data) else {
            return nil
        }
        return session
    }

    static func clearSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum ShinnAuthError: Error {
    case keychainFailed
    case invalidKey
}