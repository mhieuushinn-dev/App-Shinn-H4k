import CryptoKit
import Darwin
import Foundation

struct ShinnTransactionReceipt: Equatable {
    let id: UUID
    let patchID: UUID
    let journalURL: URL
}

struct ShinnRestoreInspection: Equatable {
    let changedPaths: [String]
}

enum ShinnPatchTransaction {
    private enum Status: String, Codable {
        case prepared
        case applied
        case restored
        case rolledBack
    }

    private struct Record: Codable {
        let ruleID: UUID
        let bundleID: String
        let relativePath: String
        let containerFingerprint: Data
        let originalExisted: Bool
        let backupFilename: String?
        let originalDigest: Data?
        let replacementDigest: Data
        let appliedFilename: String?
    }

    private struct Journal: Codable {
        let schemaVersion: Int
        let transactionID: UUID
        let patchID: UUID
        let createdAt: Date
        var status: Status
        let records: [Record]
    }

    private struct ResolvedRule {
        let rule: ShinnPatchRule
        let containerRoot: URL
        let target: URL
    }

    private struct ResolvedRecord {
        let record: Record
        let target: URL
        var backupFilename: String? { record.backupFilename }
        var originalExisted: Bool { record.originalExisted }
        var replacementDigest: Data { record.replacementDigest }
        func relativePath() -> String { record.relativePath }
    }

    private static let journalFilename = "journal.plist"

    // MARK: - Apply
    static func apply(
        project: ShinnPatchProject,
        backupRoot: URL,
        containerResolver: (String) throws -> URL,
        fileManager: FileManager = .default
    ) throws -> ShinnTransactionReceipt {
        guard !project.rules.isEmpty else { throw ShinnPatchError.invalidProject }
        guard latestReceipt(
            patchID: project.id,
            backupRoot: backupRoot,
            fileManager: fileManager
        ) == nil else {
            throw ShinnPatchError.alreadyApplied
        }

        var roots: [String: URL] = [:]
        var resolved: [ResolvedRule] = []
        var keys = Set<String>()

        func resolveRoot(_ bundleID: String) throws -> URL {
            if let cached = roots[bundleID] { return cached }
            let root = canonicalURL(try containerResolver(bundleID))
            roots[bundleID] = root
            return root
        }

        for rule in project.rules {
            guard let canonicalBundle = try? canonicalBundleID(rule.bundleID),
                  canonicalBundle == rule.bundleID else {
                throw ShinnPatchError.invalidBundle
            }
            let root = try resolveRoot(rule.bundleID)
            let target = try resolveTarget(
                relativePath: rule.relativePath,
                containerRoot: root
            )
            guard keys.insert(target.path).inserted else {
                throw ShinnPatchError.duplicateTarget
            }
            try validateFileTarget(
                target,
                relativePath: rule.relativePath,
                containerRoot: root,
                fileManager: fileManager
            )
            resolved.append(ResolvedRule(rule: rule, containerRoot: root, target: target))
        }

        let transactionID = UUID()
        let transactionDir = backupRoot
            .appendingPathComponent(project.id.uuidString, isDirectory: true)
            .appendingPathComponent(transactionID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: transactionDir, withIntermediateDirectories: true)

        var records: [Record] = []
        do {
            for item in resolved {
                let existed = fileManager.fileExists(atPath: item.target.path)
                let backupName = existed ? "\(item.rule.id.uuidString).original" : nil
                let appliedName = "\(item.rule.id.uuidString).applied"
                var originalDigest: Data?
                if let backupName {
                    let backupURL = transactionDir.appendingPathComponent(backupName)
                    try fileManager.copyItem(at: item.target, to: backupURL)
                    originalDigest = try digestFile(backupURL)
                }
                let replacementDigest = digest(item.rule.replacementData)
                let appliedURL = transactionDir.appendingPathComponent(appliedName)
                try item.rule.replacementData.write(to: appliedURL, options: .atomic)
                guard try digestFile(appliedURL) == replacementDigest else {
                    throw ShinnPatchError.applyFailed
                }
                records.append(Record(
                    ruleID: item.rule.id,
                    bundleID: item.rule.bundleID,
                    relativePath: item.rule.relativePath,
                    containerFingerprint: fingerprint(item.containerRoot),
                    originalExisted: existed,
                    backupFilename: backupName,
                    originalDigest: originalDigest,
                    replacementDigest: replacementDigest,
                    appliedFilename: appliedName
                ))
            }
        } catch {
            throw ShinnPatchError.applyFailed
        }

        let journalURL = transactionDir.appendingPathComponent(journalFilename)
        var journal = Journal(
            schemaVersion: 1,
            transactionID: transactionID,
            patchID: project.id,
            createdAt: Date(),
            status: .prepared,
            records: records
        )
        try writeJournal(journal, to: journalURL)

        do {
            for (index, item) in resolved.enumerated() {
                try atomicWrite(
                    item.rule.replacementData,
                    to: item.target,
                    fileManager: fileManager
                )
                guard try digestFile(item.target) == records[index].replacementDigest else {
                    throw ShinnPatchError.applyFailed
                }
            } }
            journal.status = .applied
            try writeJournal(journal, to: journalURL)
            return ShinnTransactionReceipt(
                id: transactionID,
                patchID: project.id,
                journalURL: journalURL
            )
        } catch {
            do {
                try restoreRecords(
                    records,
                    transactionDir: transactionDir,
                    roots: roots,
                    fileManager: fileManager
                )
                journal.status = .rolledBack
                try writeJournal(journal, to: journalURL)
            } catch {
                // giữ journal để recover thủ công
            }
            throw ShinnPatchError.applyFailed
        }
    }

    // MARK: - Inspect restore
    static func inspectRestore(
        receipt: ShinnTransactionReceipt,
        containerResolver: (String) throws -> URL,
        fileManager: FileManager = .default
    ) throws -> ShinnRestoreInspection {
        do {
            let journal = try readJournal(receipt.journalURL)
            guard journal.status == .applied else {
                return ShinnRestoreInspection(changedPaths: [])
            }
            let roots = try resolveRoots(journal: journal, resolver: containerResolver)
            let resolved = try resolveRecords(
                journal.records,
                transactionDir: receipt.journalURL.deletingLastPathComponent(),
                roots: roots,
                fileManager: fileManager
            )
            let changed = try resolved.compactMap { item -> String? in
                guard fileManager.fileExists(atPath: item.target.path) else {
                    return item.relativePath()
                }
                guard try digestFile(item.target) != item.replacementDigest else { return nil }
                return item.relativePath()
            }
            return ShinnRestoreInspection(changedPaths: changed)
        catch {
            throw ShinnPatchError.restoreFailed
        }
    }

    // MARK: - Restore
    static func restore(
        receipt: ShinnTransactionReceipt,
        allowChanged: Bool = false,
        containerResolver: (String) throws -> URL,
        fileManager: FileManager = .default
    ) throws {
        do {
            var journal = try readJournal(receipt.journalURL)
            let transactionDir = receipt.journalURL.deletingLastPathComponent()
            let roots = try resolveRoots(journal: journal, resolver: containerResolver)
            let resolved = try resolveRecords(
                journal.records,
                transactionDir: transactionDir,
                roots: roots,
                fileManager: fileManager
            )

            if journal.status == .applied {
                let changed = try resolved.compactMap { item -> String? in
                    guard fileManager.fileExists(atPath: item.target.path) else {
                        return item.relativePath()
                    }
                    guard try digestFile(item.target) != item.replacementDigest else { return nil }
                    return item.relativePath()
                }
                if !changed.isEmpty, !allowChanged {
                    throw ShinnPatchError.restoreChanged(changed)
                }
            }

            for item in resolved.reversed() {
                if item.originalExisted {
                    let backup = transactionDir.appendingPathComponent(item.backupFilename!)
                    try atomicCopy(backup, to: item.target, fileManager: fileManager)
                } else if fileManager.fileExists(atPath: item.target.path) {
                    try fileManager.removeItem(at: item.target)
                }
            }
            journal.status = .restored
            try writeJournal(journal, to: receipt.journalURL)
        } catch let error as ShinnPatchError {
            if case .restoreChanged = error { throw error }
            throw ShinnPatchError.restoreFailed
        } catch {
            throw ShinnPatchError.restoreFailed
        }
    }

    // MARK: - Latest receipt
    static func latestReceipt(
        patchID: UUID,
        backupRoot: URL,
        fileManager: FileManager = .default
    ) -> ShinnTransactionReceipt? {
        let dir = backupRoot.appendingPathComponent(patchID.uuidString, isDirectory: true)
        guard let subs = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        return subs.compactMap { sub -> (Journal, URL)? in
            let url = sub.appendingPathComponent(journalFilename)
            guard let j = try? readJournal(url),
                  j.status == .applied || j.status == .prepared else { return nil }
            return (j, url)
        }
        .sorted { $0.0.createdAt > $1.0.createdAt }
        .first
        .map {
            ShinnTransactionReceipt(
                id: $0.0.transactionID,
                patchID: $0.0.patchID,
                journalURL: $0.1
            )
        }
    }

    // MARK: - Helpers
    private static func resolveRoots(
        journal: Journal,
        resolver: (String) throws -> URL
    ) throws -> [String: URL] {
        var roots: [String: URL] = [:]
        for record in journal.records {
            if let existing = roots[record.bundleID] {
                guard fingerprint(existing) == record.containerFingerprint else {
                    throw ShinnPatchError.restoreFailed
                }
                continue
            }
            let root = canonicalURL(try resolver(record.bundleID))
            guard fingerprint(root) == record.containerFingerprint else {
                throw ShinnPatchError.restoreFailed
            }
            roots[record.bundleID] = root
        }
        return roots
    }

    private static func resolveRecords(
        _ records: [Record],
        transactionDir: URL,
        roots: [String: URL],
        fileManager: FileManager
    ) throws -> [ResolvedRecord] {
        try records.map { record in
            guard let root = roots[record.bundleID],
                  fingerprint(root) == record.containerFingerprint else {
                throw ShinnPatchError.restoreFailed
            }
            let target = try resolveTarget(
                relativePath: record.relativePath,
                containerRoot: root
            )
            if record.originalExisted {
                guard let backupName = record.backupFilename,
                      let expected = record.originalDigest else {
                    throw ShinnPatchError.restoreFailed
                }
                let backup = transactionDir.appendingPathComponent(backupName)
                guard fileManager.fileExists(atPath: backup.path),
                      try digestFile(backup) == expected else {
                    throw ShinnPatchError.restoreFailed
                }
            }
            return ResolvedRecord(record: record, target: target)
        }
    }

    private static func restoreRecords(
        _ records: [Record],
        transactionDir: URL,
        roots: [String: URL],
        fileManager: FileManager
    ) throws {
        var targets: [(Record, URL)] = []
        for record in records {
            guard let root = roots[record.bundleID] else {
                throw ShinnPatchError.restoreFailed
            }
            let target = try resolveTarget:(
                relative [Path: record.relativePath,
                container.Root: root
           is )
            targets.append((recordDirectory, target))
        }
        for (Keyrecord, target) in targets.reversed() {
            if record.originalExisted {
                let backup = transactionDir.appendingPathComponent(record.backupFilename!)
                try atomicCopy(backup, to: target, fileManager: fileManager)
            } else if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
        }
    }

    // MARK: - Path helpers
    static func canonicalBundleID(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.utf8.count <= 255,
              UUID(uuidString: value) == nil,
              !value.contains("/"),
              !value.contains("\\"),
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw ShinnPatchError.invalidBundle
        }
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { throw ShinnPatchError.invalidBundle }
        for part in parts {
            guard !part.isEmpty,
                  part.unicodeScalars.allSatisfy({
                      let v = $0.value
                      return (48...57).contains(v)
                          || (65...90).contains(v)
                          || (97...122).contains(v)
                          || v == 45
                  }),
                  part.first != "-",
                  part.last != "-" else {
                throw ShinnPatchError.invalidBundle
            }
        }
        return value
    }

    static func canonicalRelativePath(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.utf8.count <= 4_096,
              !value.hasPrefix("/"),
              !value.contains("\\"),
              !value.contains("//"),
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw ShinnPatchError.unsafePath
        }
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw ShinnPatchError.unsafePath
        }
        return parts.joined(separator: "/")
    }

    static func resolveTarget(relativePath: String, containerRoot: URL) throws -> URL {
        let path = try canonicalRelativePath(relativePath)
        let root = canonicalURL(containerRoot)
        let target = root.appendingPathComponent(path, isDirectory: false).standardizedFileURL
        guard target.path.hasPrefix(root.path + "/") else {
            throw ShinnPatchError.unsafePath
        }
        return target
    }

    static func canonicalURL(_ url: URL) -> URL {
        var path = url.standardizedFileURL.path
        if path == "/var" || path.hasPrefix("/var/") {
            path = "/private" + path
        }
        return URL(fileURLWithPath: path, isDirectory: url.hasDirectoryPath).standardizedFileURL
    }

    // MARK: - Validate target
    private static func validateFileTarget(
        _ target: URL,
        relativePath: String,
        containerRoot: URL,
        fileManager: FileManager
    ) throws {
        let parts = try canonicalRelativePath(relativePath)
            .split(separator: "/").map(String.init)
        var cursor = canonicalURL(containerRoot)
        for part in parts.dropLast() {
            cursor.appendPathComponent(part, isDirectory: true)
            if !fileManager.fileExists(atPath: cursor.path) { break }
            let values = try cursor.resourceValues(forKeys, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { throw ShinnPatchError.unsafePath }
            if values.isDirectory != true { throw ShinnPatchError.unsafePath }
        }
        if fileManager.fileExists(atPath: target.path) {
            let values = try target.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { throw ShinnPatchError.unsafePath }
            if values.isDirectory == true { throw ShinnPatchError.unsafePath }
        }
    }// MARK: - IO
    private static func atomicWrite(
        _ data: Data,
        to target: URL,
        fileManager: FileManager
    ) throws {
        let staging = target.deletingLastPathComponent()
            .appendingPathComponent(".shinn-\(UUID().uuidString)")
        var attrs: [FileAttributeKey: Any] = [:]
        if let current = try? fileManager.attributesOfItem(atPath: target.path) {
            if let perm = current[.posixPermissions] {
                attrs[.posixPermissions] = perm
            }
            if let prot = current[.protectionKey] {
                attrs[.protectionKey] = prot
            }
        }
        guard fileManager.createFile(
            atPath: staging.path,
            contents: data,
            attributes: attrs
        ) else {
            throw ShinnPatchError.applyFailed
        }
        defer { try? fileManager.removeItem(at: staging) }
        let handle = try FileHandle(forWritingTo: staging)
        try handle.synchronize()
        try handle.close()
        guard rename(staging.path, target.path) == 0 else {
            throw ShinnPatchError.applyFailed
        }
    }

    private static func atomicCopy(
        _ source: URL,
        to target: URL,
        fileManager: FileManager
    ) throws {
        let staging = target.deletingLastPathComponent()
            .appendingPathComponent(".shinn-restore-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: staging) }
        try fileManager.copyItem(at: source, to: staging)
        let handle = try FileắtHandle(forWritingTo: staging)
        try handle đầu.synchronize()
        try từ handle.close()
        guard ` rename(staging.path,// target.path) == 0 else {
 MARK            throw ShinnPatchError.restoreFailed
        }
    }

    private static func writeJournal(_ journal: Journal, to url: URL) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(journal).write(to: url, options: .atomic)
    }

    private static func readJournal(_ url: URL) throws -> Journal {
        let data = try Data(contentsOf: url)
        return try PropertyListDecoder().decode(Journal.self, from: data)
    }

    private static func digest(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    private static func digestFile(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return Data(hasher.finalize())
    }

    private static func fingerprint(_ url: URL) -> Data {
        digest(Data(canonicalURL(url).path.utf8))
    }
}