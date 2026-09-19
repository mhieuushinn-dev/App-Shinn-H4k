import SwiftUI

struct SettingsView: View {
    @Environment(\.shinnLanguage) private var language
    @EnvironmentObject private var appState: ShinnAppState
    @AppStorage(ShinnLanguage.storageKey)
    private var languageCode = ShinnLanguage.vietnamese.rawValue
    @State private var showLogoutConfirm = false
    @State private var showLogs = false
    @State private var showTerms = false

    var body: some View {
        ZStack {
            ShinnTheme.background.ignoresSafeArea()

            List {
                // Ngôn ngữ
                Section {
                    Picker(selection: $languageCode) {
                        ForEach(ShinnLanguage.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    } label: {
                        Label(ShinnText.settingsLanguage(language), systemImage: "globe")
                            .foregroundStyle(.white)
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                } header: {
                    sectionHeader(ShinnText.settingsLanguage(language))
                }
                .listRowBackground(ShinnTheme.cardBackground)

                // Tài khoản
                Section {
                    HStack {
                        Label(ShinnText.infoRole(language), systemImage: "person.fill")
                            .foregroundStyle(.white)
                        Spacer()
                        if let role = appState.session?.role {
                            Text(language == .vietnamese ? role.displayNameVI : role.displayNameEN)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    if let username = appState.session?.username, !username.isEmpty {
                        HStack {
                            Label(ShinnText.usernamePlaceholder(language), systemImage: "at")
                                .foregroundStyle(.white)
                            Spacer()
                            Text(username)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                } header: {
                    sectionHeader(ShinnText.infoAccountSection(language))
                }
                .listRowBackground(ShinnTheme.cardBackground)

                // Tiện ích
                Section {
                    Button {
                        showLogs = true
                    } label: {
                        Label(ShinnText.settingsLogs(language), systemImage: "apple.terminal")
                            .foregroundStyle(.white)
                    }
                    Button {
                        showTerms = true
                    } label: {
                        Label(ShinnText.settingsLegal(language), systemImage: "doc.text")
                            .foregroundStyle(.white)
                    }
                } header: {
                    sectionHeader(language == .vietnamese ? "Tiện ích" : "Utilities")
                }
                .listRowBackground(ShinnTheme.cardBackground)

                // Đăng xuất
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Label(
                            ShinnText.settingsLogout(language),
                            systemImage: "rectangle.portrait.and.arrow.right"
                        )
                        .foregroundStyle(ShinnTheme.danger)
                    }
                }
                .listRowBackground(ShinnTheme.cardBackground)

                // Phiên bản
                Section {
                    HStack {
                        Text("Shinn H4K")
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text(appVersion)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .font(.system(size: 12))
                }
                .listRowBackground(ShinnTheme.cardBackground)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(ShinnText.tabSettings(language))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            ShinnText.settingsLogout(language),
            isPresented: $showLogoutConfirm
        ) {
            Button(ShinnText.cancel(language), role: .cancel) {
                // Đóng alert, không làm gì
            }
            Button(ShinnText.settingsLogout(language), role: .destructive) {
                appState.signOut()
            }
        } message: {
            Text(ShinnText.settingsLogoutConfirm(language))
        }
        .sheet(isPresented: $showLogs) {
            NavigationStack {
                LogView()
            }
        }
        .sheet(isPresented: $showTerms) {
            NavigationStack {
                TermsReaderView()
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.5))
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }
}