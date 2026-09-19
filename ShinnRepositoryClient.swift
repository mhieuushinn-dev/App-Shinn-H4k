import Combine
import Foundation

// MARK: - Redirect delegate
private final class ShinnRepositoryRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url,
              (try? ShinnRepositoryValidator.validateURL(url)) != nil else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

// MARK: - Store
@MainActor
final class ShinnRepositoryStore: ObservableObject {
    @Published private(set) var sources: [ShinnRepositorySource] = []
    @Published private(set) var manifests: [UUID: ShinnRepositoryManifest] = [:]
    @Published private(set) var states: [UUID: ShinnRepositoryState] = [:]
    @Published private(set) var downloadingPackageIDs: Set<String> = []

    private var loadedForRole: ShinnRole?
    private var refreshed = false

    init() {
        sources = ShinnRepositoryKind.allCases.map {
            ShinnRepositorySource(kind: $0)
        }
        for source in sources {
            states[source.id] = .idle
        }
    }

    var isRefreshing: Bool {
        states.values.contains(.loading)
    }

    func manifest(for source: ShinnRepositorySource) -> ShinnRepositoryManifest? {
        manifests[source.id]
    }

    func state(for id: UUID) -> ShinnRepositoryState {
        states[id] ?? .idle
    }

    // MARK: - Load
    func loadIfNeeded(role: ShinnRole?) {
        guard let role else { return }
        if loadedForRole == role, refreshed { return }
        loadedForRole = role
        refreshed = true
        Task { await refreshAll(role: role) }
    }

    func refreshAllAndWait(role: ShinnRole?) async {
        await refreshAll(role: role)
        while isRefreshing {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func refreshAll(role: ShinnRole?) async {
        let accessible = accessibleSources(for: role)
        await withTaskGroup(of: Void.self) { group in
            for source in accessible {
                group.addTask { [weak self] in
                    await self?.refresh(source)
                }
            }
        }
    }

    func refresh(_ source: ShinnRepositorySource) async {
        states[source.id] = .loading
        do {
            let data = try await ShinnRepositoryNetworkClient.downloadManifest(
                from: source.manifestURL
            )
            let manifest = try ShinnRepositoryValidator.validate(
                data: data,
                kind: source.kind,
                sourceURL: source.manifestURL
            )
            manifests[source.id] = manifest
            states[source.id] = .loaded(Date())
            log("shinnh4k: loaded \(manifest.identifier) packages=\(manifest.packages.count)")
        } catch let error as ShinnRepositoryError {
            manifests[source.id] = nil
            states[source.id] = .failed(error)
            log("shinnh4k: repo failed kind=\(source.kind.rawValue)")
        } catch {
            manifests[source.id] = nil
            states[source.id] = .failed(.sourceUnavailable)
            log("shinnh4k: repo failed kind=\(source.kind.rawValue) unknown")
        }
    }

    // MARK: - Remove source (Owner/Admin only)
    func removeSource(_ source: ShinnRepositorySource) {
        sources.removeAll { $0.id == source.id }
        manifests[source.id] = nil
        states[source.id] = nil
        log("shinnh4k: removed source kind=\(source.kind.rawValue)")
    }

    // MARK: - Download package
    func download(
        _ package: ShinnRepositoryPackage,
        role: ShinnRole?,
        patchStore: ShinnPatchStore
    ) async {
        guard let role, role.canDownloadPackage else {
            log("shinnh4k: download blocked by role")
            return
        }
        guard !downloadingPackageIDs.contains(package.id) else { return }
        downloadingPackageIDs.insert(package.id)
        defer { downloadingPackageIDs.remove(package.id) }

        do {
            let fileURL = try await ShinnRepositoryNetworkClient.downloadPackage(
                package
            )
            defer { try? FileManager.default.removeItem(at: fileURL) }
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            await patchStore.install(
                data: data,
                package: package
            )
        } catch let error as ShinnRepositoryError {
            log("shinnh4k: download failed \(package.identifier) — \(error)")
            await patchStore.presentError(error)
        } catch {
            log("shinnh4k: download failed \(package.identifier) — unknown")
            await patchStore.presentError(.sourceUnavailable)
        }
    }

    // MARK: - Access control
    private func accessibleSources(for role: ShinnRole?) -> [ShinnRepositorySource] {
        guard let role else { return [] }
        return sources.filter { source in
            switch source.kind {
            case .shinnThieuu: return role.canAccessShinnThieuu
            case .shinnChest: return role.canAccessShinnChest
            }
        }
    }
}

// MARK: - Network client
enum ShinnRepositoryNetworkClient {
    static func downloadManifest(from url: URL) async throws -> Data {
        let trusted = try ShinnRepositoryValidator.validateURL(url)
        let fileURL = try await downloadFile(from: trusted, maximumBytes: 10 * 1_024 * 1_024)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        return try Data(contentsOf: fileURL, options: .mappedIfSafe)
    }

    static func downloadPackage(_ package: ShinnRepositoryPackage) async throws -> URL {
        let trusted = try ShinnRepositoryValidator.validateURL(package.downloadURL)
        let maximumBytes = package.expectedSize
            .map { Int($0) + 4 * 1_024 * 1_024 }
            ?? 64 * 1_024 * 1_024
        let fileURL = try await downloadFile(from: trusted, maximumBytes: maximumBytes)

        // Verify kích thước nếu có
        if let expected = package.expectedSize {
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
            if size != expected {
                try? FileManager.default.removeItem(at: fileURL)
                throw ShinnRepositoryError.checksumMismatch
            }
        }

        // Verify SHA-256 nếu có
        if let sha = package.sha256 {
            let actual = try ShinnDigest.sha256Hex(fileURL: fileURL)
            guard actual.caseInsensitiveCompare(sha) == .orderedSame else {
                try? FileManager.default.removeItem(at: fileURL)
                throw ShinnRepositoryError.checksumMismatch
            }
        } else {
            // Không có SHA-256 → từ chối
            try? FileManager.default.removeItem(at: fileURL)
            throw ShinnRepositoryError.checksumMismatch
        }
        return fileURL
    }

    private static func downloadFile(
        from rawURL: URL,
        maximumBytes: Int
    ) async throws -> URL {
        let url = try ShinnRepositoryValidator.validateURL(rawURL)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let delegate = ShinnRepositoryRedirectDelegate()
        let session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: url)
        request.setValue("ShinnH4K/1.0.0", forHTTPHeaderField: "User-Agent")

        let (tempURL, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let finalURL = response.url,
              (try? ShinnRepositoryValidator.validateURL(finalURL)) != nil else {
            throw ShinnRepositoryError.sourceUnavailable
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        guard size > 0, size <= maximumBytes else {
            throw ShinnRepositoryError.packageTooLarge
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension.isEmpty ? "bin" : url.pathExtension)
        do {
            try FileManager.default.moveItem(at: tempURL, to: destination)
            return destination
        } catch {
            throw ShinnRepositoryError.sourceUnavailable
        }
    }
}