import Foundation
import UIKit
import Darwin
import Combine

// MARK: - Global log
final class ShinnLog: ObservableObject {
    static let shared = ShinnLog()
    @Published var entries: [String] = []

    func append(_ msg: String) {
        DispatchQueue.main.async { self.entries.append(msg) }
    }
}

func log(_ msg: String) {
    ShinnLog.shared.append("[ShinnH4K] \(msg)")
}

// MARK: - Stdout/stderr capture
private var shinnLogPipe: Pipe?

func setupLogCapture() {
    guard shinnLogPipe == nil else { return }
    let pipe = Pipe()
    shinnLogPipe = pipe
    setvbuf(stdout, nil, _IONBF, 0)
    setvbuf(stderr, nil, _IONBF, 0)
    let writeFD = pipe.fileHandleForWriting.fileDescriptor
    if dup2(writeFD, STDOUT_FILENO) < 0 || dup2(writeFD, STDERR_FILENO) < 0 {
        log("setupLogCapture: dup2 failed")
        shinnLogPipe = nil
        return
    }
    pipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            DispatchQueue.main.async { ShinnLog.shared.append(trimmed) }
        }
    }
}

// MARK: - AppInfo
enum AppInfo {
    static var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    static var versionTuple: (major: Int, minor: Int, patch: Int) {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return (v.majorVersion, v.minorVersion, v.patchVersion)
    }

    static var osBuild: String {
        var size: size_t = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0, size > 0 else {
            return "Unknown"
        }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &value, &size, nil, 0) == 0 else {
            return "Unknown"
        }
        return String(cString: value)
    }

    static var machineName: String {
        var s = utsname()
        uname(&s)
        return Mirror(reflecting: s.machine).children.reduce("") { id, e in
            guard let v = e.value as? Int8, v != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(v)))
        }
    }

    static var displayMachineName: String {
#if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machineName
#else
        return machineName
#endif
    }
}

// MARK: - Exploit Status
enum ExploitStatus: Equatable {
    case notStarted
    case success(method: String)
    case failed(method: String, code: Int64)
    case unsupported(String)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

// MARK: - Log View
struct LogView: View {
    @Environment(\.shinnLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var logStore = ShinnLog.shared
    @State private var copied = false

    var body: some View {
        ZStack {
            ShinnTheme.background.ignoresSafeArea()
            Group {
                if logStore.entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "apple.terminal")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.white.opacity(0.4))
                        Text(language == .vietnamese
                             ? "Chưa có nhật ký"
                             : "No logs yet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(logStore.entries.enumerated()), id: \.offset) { _, entry in
                                Text(entry)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                                Divider().overlay(Color.white.opacity(0.08))
                            }
                        }
                        .padding(14)
                    }
                }
            }
        }
        .navigationTitle(ShinnText.settingsLogs(language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(language == .vietnamese ? "Xoá" : "Clear", role: .destructive) {
                    logStore.entries.removeAll()
                }
                .disabled(logStore.entries.isEmpty)
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    UIPasteboard.general.string = logStore.entries.joined(separator: "\n")
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .disabled(logStore.entries.isEmpty)

                Button(ShinnText.close(language)) { dismiss() }
                    .foregroundStyle(.white)
            }
        }
    }
}