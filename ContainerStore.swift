import Foundation
import Darwin
import UIKit

struct ShinnInstalledApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let containerPath: String
    let version: String

    var id: String { bundleID }
}

enum ContainerStore {
    static let appDataRoot = "/var/mobile/Containers/Data/Application"

    private static var shouldUseBadQuery: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
    }

    // MARK: - Resolve container by bundleID (MHA-C2)
    static func resolveAppContainerPath(bundleID: String) -> String? {
        guard (try? ShinnPatchTransaction.canonicalBundleID(bundleID)) == bundleID else {
            return nil
        }
        var lookupError: NSString?
        if let path = MCMActivateContainerPath(2, bundleID, false, &lookupError),
           isApplicationContainerPath(path) {
            log("patch: MHA-C2 resolved \(bundleID)")
            return path
        }
        let detail = lookupError.map(String.init) ?? "unavailable"
        log("patch: MHA-C2 could not resolve \(bundleID), detail=\(detail)")

        if let scanned = resolveByMetadataScan(bundleID: bundleID) {
            log("patch: filesystem scan resolved \(bundleID)")
            return scanned
        }
        return nil
    }

    static func resolveByMetadataScan(bundleID: String) -> String? {
        if KernelExploit.requiresSandboxEscape, !KernelExploit.hasSandboxAccess() {
            log("patch: metadata scan skipped — sandbox access not active")
            return nil
        }
        let dirs = enumerateDirectories(path: appDataRoot)
        guard !dirs.isEmpty else { return nil }
        for dir in dirs {
            guard UUID(uuidString: (dir as NSString).lastPathComponent) != nil else { continue }
            guard let meta = readContainerMetadata(containerPath: dir),
                  meta.bundleID == bundleID else { continue }
            let canonical = canonicalPath(dir)
            guard isApplicationContainerPath(canonical) else { continue }
            return canonical
        }
        return nil
    }

    static func isApplicationContainerPath(_ path: String) -> Bool {
        let root = canonicalPath(appDataRoot)
        let p = canonicalPath(path)
        guard p.hasPrefix(root + "/") else { return false }
        return UUID(uuidString: (p as NSString).lastPathComponent) != nil
    }

    static func canonicalPath(_ rawPath: String) -> String {
        var p = (rawPath as NSString).standardizingPath
        if p == "/var" || p.hasPrefix("/var/") {
            p = "/private" + p
        }
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return p
    }

    // MARK: - Enumerate directories
    static func enumerateDirectories(path: String, maxInode: Int64 = 2_000_000) -> [String] {
        let clean = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard clean.hasPrefix("/") else { return [] }

        if let names = try? FileManager.default.contentsOfDirectory(atPath: clean),
           !names.isEmpty {
            return names.map { (clean as NSString).appendingPathComponent($0) }
        }

        var pathC = clean.utf8CString.map { Int8($0) }
        guard let result = bad_query_list(&pathC, maxInode) else {
            log("enumerate: NULL for \(clean)")
            return []
        }
        defer { free(result) }
        let list = String(cString: result)
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
        if !list.isEmpty {
            log("enumerate: inode fallback for \(clean) -> \(list.count)")
        }
        return list
    }

    // MARK: - Metadata read
    struct ContainerMetadata {
        let bundleID: String
        let displayName: String
    }

    static func readContainerMetadata(containerPath: String) -> ContainerMetadata? {
        let metaPath = (containerPath as NSString)
            .appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")

        var data: Data?
        if let fd = fopen(metaPath, "r") {
            var buffer = [UInt8](repeating: 0, count: 65536)
            var bytes: [UInt8] = []
            while true {
                let n = fread(&buffer, 1, buffer.count, fd)
                if n <= 0 { break }
                bytes.append(contentsOf: buffer[0..<n])
            }
            fclose(fd)
            if !bytes.isEmpty { data = Data(bytes) }
        }
        if data == nil {
            data = try? Data(contentsOf: URL(fileURLWithPath: metaPath))
        }

        guard let valid = data,
              let plist = try? PropertyListSerialization.propertyList(
                from: valid,
                options: [],
                format: nil
              ) as? [String: Any] else {
            return nil
        }

        let bundleID = plist["MCMMetadataIdentifier"] as? String ?? ""
        var display = ""
        if let info = plist["MCMMetadataInfo"] as? [String: Any] {
            display = (info["CFBundleDisplayName"] as? String)
                ?? (info["CFBundleName"] as? String)
                ?? ""
        }
        return ContainerMetadata(bundleID: bundleID, displayName: display)
    }

    // MARK: - Grant access via bad_query
    static func grantContainerAccess(_ path: String) -> Int64 {
        guard shouldUseBadQuery else { return -1 }
        let clean = path.hasSuffix("/") ? String(path.dropLast()) : path
        var pathC = clean.utf8CString.map { Int8($0) }
        return bad_query(&pathC, true, nil, false)
    }
}