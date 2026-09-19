import Foundation

// MARK: - Installed Patch Model
struct ShinnInstalledPatch: Identifiable, Equatable {
    let id: UUID
    let packageID: String
    let name: String
    let bundleID: String
    let author: String
    let version: String
    let repositoryKind: ShinnRepositoryKind
    let repositoryName: String
    let packageURL: URL
    let installedAt: Date
    var isApplied: Bool
    var contentKey: Data?

    var summaryText: String {
        "\(repositoryName) · v\(version)"
    }
}

// MARK: - Installed Store (JSON local)
enum ShinnInstalledStore {
    private static let fileName = "shinnh4k.installed.json"
    private static let directoryName = "ShinnH4K"

    private struct Entry: Codable {
        let id: UUID
        let packageID: String
        let name: String
        let bundleID: String
        let author: String
        let version: String
        let repositoryKind: String
        let repositoryName: String
        let packageFileName: String
        let installedAt: Date
        var isApplied: Bool
        var contentKeyBase64: String?
    }

    static func rootURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func packagesURL(fileManager: FileManager = .default) throws -> URL {
        let url = try rootURL(fileManager: fileManager)
            .appendingPathComponent("Packages", isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func backupsURL(fileManager: FileManager = .default) throws -> URL {
        let url = try rootURL(fileManager: fileManager)
            .appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Load
    static func load(fileManager: FileManager = .default) -> [ShinnInstalledPatch] {
        guard let root = try? rootURL(fileManager: fileManager) else { return [] }
        let metaURL = root.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: metaURL),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        let packagesDir = (try? packagesURL(fileManager: fileManager))
            ?? root.appendingPathComponent("Packages", isDirectory: true)

        return entries.compactMap { entry -> ShinnInstalledPatch? in
            let packageURL = packagesDir.appendingPathComponent(entry.packageFileName)
            guard fileManager.fileExists(atPath: packageURL.path) else { return nil }
            let kind = ShinnRepositoryKind(rawValue: entry.repositoryKind) ?? .shinnThieuu
            let contentKey = entry.contentKeyBase64.flatMap { Data(base64Encoded: $0) }
            return ShinnInstalledPatch(
                id: entry.id,
                packageID: entry.packageID,
                name: entry.name,
                bundleID: entry.bundleID,
                author: entry.author,
                version: entry.version,
                repositoryKind: kind,
                repositoryName: entry.repositoryName,
                packageURL: packageURL,
                installedAt: entry.installedAt,
                isApplied: entry.isApplied,
                contentKey: contentKey
            )
        }
    }

    // MARK: - Save
    static func save(
        _ patches: [ShinnInstalledPatch],
        fileManager: FileManager = .default
    ) throws {
        let root = try rootURL(fileManager: fileManager)
        let entries = patches.map { patch -> Entry in
            Entry(
                id: patch.id,
                packageID: patch.packageID,
                name: patch.name,
                bundleID: patch.bundleID,
                author: patch.author,
                version: patch.version,
                repositoryKind: patch.repositoryKind.rawValue,
                repositoryName: patch.repositoryName,
                packageFileName: patch.packageURL.lastPathComponent,
                installedAt: patch.installedAt,
                isApplied: patch.isApplied,
                contentKeyBase64: patch.contentKey?.base64EncodedString()
            )
        }
        let data = try JSONEncoder().encode(entries)
        try data.write(
            to: root.appendingPathComponent(fileName),
            options: [.atomic, .completeFileProtection]
        )
    }

    // MARK: - Add
    static func install(
        data: Data,
        package: ShinnRepositoryPackage,
        decoded: ShinnDecodedPatch,
        fileManager: FileManager = .default
    ) throws -> ShinnInstalledPatch {
        let packagesDir = try packagesURL(fileManager: fileManager)
        let fileName = "\(package.identifier)-\(UUID().uuidString).3105"
        let destURL = packagesDir.appendingPathComponent(fileName)
        try data.write(to: destURL, options: [.atomic, .completeFileProtection])

        let patch = ShinnInstalledPatch(
            id: UUID(),
            packageID: decoded.packageID.uuidString,
            name: package.name,
            bundleID: decoded.bundleID,
            author: package.author,
            version: package.version,
            repositoryKind: package.repositoryKind,
            repositoryName: package.repositoryName,
            packageURL: destURL,
            installedAt: Date(),
            isApplied: false,
            contentKey: decoded.contentKey
        )
        var current = load(fileManager: fileManager)
        if let existingIndex = current.firstIndex(where: {
            $0.packageID == patch.packageID
        }) {
            try? fileManager.removeItem(at: current[existingIndex].packageURL)
            current[existingIndex] = patch
        } else {
            current.append(patch)
        }
        try save(current, fileManager: fileManager)
        return patch
    }

    // MARK: - Delete
    static func delete(
        _ patch: ShinnInstalledPatch,
        fileManager: FileManager = .default
    ) throws {
        var current = load(fileManager: fileManager)
        current.removeAll { $0.id == patch.id }
        try save(current, fileManager: fileManager)
        if fileManager.fileExists(atPath: patch.packageURL.path) {
            try fileManager.removeItem(at: patch.packageURL)
        }
        let backups = try backupsURL(fileManager: fileManager)
        let patchBackup = backups.appendingPathComponent(patch.packageID, isDirectory: true)
        if fileManager.fileExists(atPath: patchBackup.path) {
            try? fileManager.removeItem(at: patchBackup)
        }
    }

    // MARK: - Update state
    static func markApplied(
        _ patchID: UUID,
        applied: Bool,
        fileManager: FileManager = .default
    ) throws {
        var current = load(fileManager: fileManager)
        if let idx = current.firstIndex(where: { $0.id == patchID }) {
            current[idx].isApplied = applied
            try save(current, fileManager: fileManager)
        }
    }
}