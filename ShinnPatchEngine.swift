import Foundation

enum ShinnPatchEngine {
    // MARK: - Apply
    static func apply(project: ShinnPatchProject) throws -> ShinnTransactionReceipt {
        let bundles = orderedBundles(project)
        let roots = try resolveContainers(bundles: bundles)
        return try ShinnPatchTransaction.apply(
            project: project,
            backupRoot: try ShinnInstalledStore.backupsURL(),
            containerResolver: { bundleID in
                guard let root = roots[bundleID] else {
                    throw ShinnPatchError.targetAppUnavailable(bundleID)
                }
                return root
            }
        )
    }

    // MARK: - Inspect
    static func inspectRestore(receipt: ShinnTransactionReceipt) throws -> ShinnRestoreInspection {
        let bundles = try requiredBundles(receipt: receipt)
        let roots = try resolveContainers(bundles: bundles)
        return try ShinnPatchTransaction.inspectRestore(
            receipt: receipt,
            containerResolver: { bundleID in
                guard let root = roots[bundleID] else {
                    throw ShinnPatchError.targetAppUnavailable(bundleID)
                }
                return root
            }
        )
    }

    // MARK: - Restore
    static func restore(
        receipt: ShinnTransactionReceipt,
        allowChanged: Bool = false
    ) throws {
        let bundles = try requiredBundles(receipt: receipt)
        let roots = try resolveContainers(bundles: bundles)
        try ShinnPatchTransaction.restore(
            receipt: receipt,
            allowChanged: allowChanged,
            containerResolver: { bundleID in
                guard let root = roots[bundleID] else {
                    throw ShinnPatchError.targetAppUnavailable(bundleID)
                }
                return root
            }
        )
    }

    // MARK: - Container resolution
    private static func resolveContainers(bundles: [String]) throws -> [String: URL] {
        var result: [String: URL] = [:]
        for bundleID in bundles {
            guard let raw = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
                  ContainerStore.isApplicationContainerPath(raw) else {
                throw ShinnPatchError.targetAppUnavailable(bundleID)
            }
            result[bundleID] = ShinnPatchTransaction.canonicalURL(
                URL(fileURLWithPath: raw, isDirectory: true)
            )
        }
        return result
    }

    private static func orderedBundles(_ project: ShinnPatchProject) -> [String] {
        var seen = Set<String>()
        return project.bundleIdentifiers.filter { seen.insert($0).inserted }
    }

    private static func requiredBundles(receipt: ShinnTransactionReceipt) throws -> [String] {
        let data = try Data(contentsOf: receipt.journalURL)
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any]
        let records = plist?["records"] as? [[String: Any]] ?? []
        var seen = Set<String>()
        return records.compactMap { record in
            guard let bundle = record["bundleID"] as? String else { return nil }
            return seen.insert(bundle).inserted ? bundle : nil
        }
    }
}