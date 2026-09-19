import Combine
import Foundation

@MainActor
final class ShinnPatchStore: ObservableObject {
    @Published private(set) var installed: [ShinnInstalledPatch] = []
    @Published private(set) var isBusy = false
    @Published var alert: ShinnPatchAlert?
    @Published var unlockRequest: ShinnUnlockRequest?

    private var pendingUnlock: (data: Data, package: ShinnRepositoryPackage)?

    init() {
        installed = ShinnInstalledStore.load()
    }

    func reload() {
        installed = ShinnInstalledStore.load()
    }

    // MARK: - Install from repository
    func install(
        data: Data,
        package: ShinnRepositoryPackage
    ) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let summary = try ShinnPatchPackageCodec.inspect(data)
            if summary.isPasswordProtected {
                pendingUnlock = (data: data, package: package)
                unlockRequest = ShinnUnlockRequest(
                    packageName: package.name,
                    packageID: summary.packageID
                )
                return
            }
            let decoded = try ShinnPatchPackageCodec.decode(data, password: nil)
            _ = try ShinnInstalledStore.install(
                data: data,
                package: package,
                decoded: decoded
            )
            reload()
            alert = ShinnPatchAlert(
                title: "Đã tải",
                message: "\(package.name) đã được thêm vào Đã cài."
            )
        } catch let error as ShinnPatchError {
            present(error)
        } catch {
            present(.corrupted)
        }
    }

    func unlock(password: String) {
        guard let pending = pendingUnlock, !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let decoded = try ShinnPatchPackageCodec.decode(
                    pending.data,
                    password: password
                )
                let _ = try ShinnInstalledStore.install(
                    data: pending.data,
                    package: pending.package,
                    decoded: decoded
                )
                pendingUnlock = nil
                unlockRequest = nil
                reload()
                alert = ShinnPatchAlert(
                    title: "Đã tải",
                    message: "\(pending.package.name) đã được thêm vào Đã cài."
                )
            } catch let error as ShinnPatchError {
                present(error)
            } catch {
                present(.wrongPassword)
            }
        }
    }

    func cancelUnlock() {
        pendingUnlock = nil
        unlockRequest = nil
        isBusy = false
    }

    // MARK: - Apply
    func apply(_ item: ShinnInstalledPatch) async {
        guard !isBusy else { return }
        guard let contentKey = item.contentKey else {
            present(.keychainFailed)
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let data = try Data(contentsOf: item.packageURL, options: .mappedIfSafe)
            let decoded = try ShinnPatchPackageCodec.decode(data, contentKey: contentKey)
            _ = try ShinnPatchEngine.apply(project: decoded.project)
            try ShinnInstalledStore.markApplied(item.id, applied: true)
            reload()
            alert = ShinnPatchAlert(
                title: "Đã áp dụng",
                message: "\(item.name) đã được áp dụng."
            )
        } catch let error as ShinnPatchError {
            present(error)
        } catch {
            present(.applyFailed)
        }
    }

    // MARK: - Restore
    func restore(_ item: ShinnInstalledPatch) async {
        guard !isBusy else { return }
        guard let receipt = ShinnPatchTransaction.latestReceipt(
            patchID: UUID(uuidString: item.packageID) ?? item.id,
            backupRoot: (try? ShinnInstalledStore.backupsURL())
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
        ) else {
            present(.restoreFailed)
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let inspection = try ShinnPatchEngine.inspectRestore(receipt: receipt)
            if !inspection.changedPaths.isEmpty {
                let preview = inspection.changedPaths.prefix(3).joined(separator: ", ")
                alert = ShinnPatchAlert(
                    title: "Cảnh báo",
                    message: "Đã phát hiện thay đổi ở: \(preview)...\nÁp dụng khôi phục sẽ ghi đè."
                )
            }
            try ShinnPatchEngine.restore(receipt: receipt, allowChanged: true)
            try ShinnInstalledStore.markApplied(item.id, applied: false)
            reload()
            alert = ShinnPatchAlert(
                title: "Đã khôi phục",
                message: "\(item.name) đã được khôi phục."
            )
        } catch let error as ShinnPatchError {
            present(error)
        } catch {
            present(.restoreFailed)
        }
    }

    // MARK: - Delete
    func delete(_ item: ShinnInstalledPatch) {
        do {
            try ShinnInstalledStore.delete(item)
            reload()
        } catch let error as ShinnPatchError {
            present(error)
        } catch {
            present(.invalidProject)
        }
    }

    // MARK: - Error presentation
    func presentError(_ error: ShinnRepositoryError) async {
        alert = ShinnPatchAlert(
            title: "Lỗi",
            message: error.localizationKey
        )
    }

    private func present(_ error: ShinnPatchError) {
        alert = ShinnPatchAlert(
            title: "Lỗi",
            message: error.localizationKey
        )
    }
}

// MARK: - Alert
struct ShinnPatchAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - Unlock Request
struct ShinnUnlockRequest: Identifiable {
    let id = UUID()
    let packageName: String
    let packageID: UUID
}