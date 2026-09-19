import SwiftUI

@main
struct ShinnH4KApp: App {
    @StateObject private var appState = ShinnAppState()
    @StateObject private var repositoryStore = ShinnRepositoryStore()
    @StateObject private var patchStore = ShinnPatchStore()
    @AppStorage(ShinnLanguage.storageKey)
    private var languageCode = ShinnLanguage.vietnamese.rawValue
    @State private var showOnboarding = ShinnOnboardingStore.shouldShow()
    @Environment(\.scenePhase) private var scenePhase

    private var language: ShinnLanguage {
        ShinnLanguage(rawValue: languageCode) ?? .vietnamese
    }

    init() {
        setupLogCapture()
        log("shinnh4k: launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showOnboarding {
                    OnboardingView {
                        ShinnOnboardingStore.markCompleted()
                        withAnimation(.easeInOut(duration: 0.24)) {
                            showOnboarding = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(2)
                } else if appState.session == nil {
                    AuthGateView(appState: appState)
                        .transition(.opacity)
                        .zIndex(1)
                } else {
                    RootView()
                        .environmentObject(appState)
                        .environmentObject(repositoryStore)
                        .environmentObject(patchStore)
                        .transition(.opacity)
                        .zIndex(0)
                }
            }
            .environment(\.shinnLanguage, language)
            .environment(\.locale, language.locale)
            .preferredColorScheme(.dark)
            .tint(ShinnTheme.accent)
            .onAppear {
                appState.bootstrap()
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                appState.detectSupport()
            }
        }
    }
}

// MARK: - App State
@MainActor
final class ShinnAppState: ObservableObject {
    @Published var session: ShinnSession?
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false
    @Published var isBootstrapped = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func bootstrap() {
        guard !isBootstrapped else { return }
        isBootstrapped = true

        if let stored = ShinnAuthService.loadSession() {
            session = stored
            log("shinnh4k: restored session role=\(stored.role.rawValue)")
        }
        detectSupport()
    }

    func signIn(role: ShinnRole, username: String?, rawKey: String) {
        let session = ShinnSession.make(
            role: role,
            username: username,
            rawKey: rawKey
        )
        do {
            try ShinnAuthService.persist(session: session)
            self.session = session
            log("shinnh4k: signed in role=\(role.rawValue)")
        } catch {
            log("shinnh4k: failed to persist session")
        }
    }

    func signOut() {
        ShinnAuthService.clearSession()
        session = nil
        log("shinnh4k: signed out")
    }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )

        unsupportedMessage = supported
            ? nil
            : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"

        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major, minor: v.minor, patch: v.patch, build: AppInfo.osBuild
        )
        guard applicable else { return }

        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        log("shinnh4k: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                    log("shinnh4k: existing sandbox access still active")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
                log("shinnh4k: sandbox access no longer active")
            }
        }
    }

    func runKernelExploitIfNeeded() {
        refreshKernelExploitStatus()
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        log("shinnh4k: running kernel exploit on background…")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: "kexploit")
                    if KernelExploit.requiresSandboxEscape {
                        log("shinnh4k: kernel exploit success — sandbox access verified")
                    } else {
                        log("shinnh4k: kernel exploit success — kernel access active")
                    }
                } else {
                    self.exploitStatus = .failed(method: "kexploit", code: -1)
                    log("shinnh4k: kernel exploit FAILED — relaunch the app before retrying")
                }
            }
        }
    }
}

// MARK: - Onboarding Store
enum ShinnOnboardingStore {
    static let completedVersionKey = "shinn.onboarding.completedVersion"

    static var currentVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(v) (\(b))"
    }

    static func shouldShow() -> Bool {
        UserDefaults.standard.string(forKey: completedVersionKey) != currentVersion
    }

    static func markCompleted() {
        UserDefaults.standard.set(currentVersion, forKey: completedVersionKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: completedVersionKey)
    }
}

// MARK: - Environment Key
private struct ShinnLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue = ShinnLanguage.vietnamese
}

extension EnvironmentValues {
    var shinnLanguage: ShinnLanguage {
        get { self[ShinnLanguageEnvironmentKey.self] }
        set { self[ShinnLanguageEnvironmentKey.self] = newValue }
    }
}