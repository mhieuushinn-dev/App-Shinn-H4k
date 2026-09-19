// MARK: - IO (tiếp)
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
        let handle = try FileHandle(forWritingTo: staging)
        try handle.synchronize()
        try handle.close()
        guard rename(staging.path, target.path) == 0 else {
            throw ShinnPatchError.restoreFailed
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