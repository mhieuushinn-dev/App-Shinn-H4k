import SwiftUI
import UIKit

struct InfoView: View {
    @Environment(\.shinnLanguage) private var language
    @EnvironmentObject private var appState: ShinnAppState
    @State private var copiedAccount = false
    @State private var copiedNote = false
    @State private var showLogs = false
    @State private var showTerms = false

    private var session: ShinnSession? { appState.session }
    private var role: ShinnRole? { session?.role }

    var body: some View {
        ZStack {
            ShinnTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    appCard
                    accountCard
                    systemCard
                    contactCard
                    donateCard
                    actionCard
                }
                .padding(.horizontal, ShinnTheme.pageInset)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(ShinnText.tabInfo(language))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogs) {
            NavigationStack { LogView() }
        }
        .sheet(isPresented: $showTerms) {
            NavigationStack { TermsReaderView() }
        }
    }

    private var appCard: some View {
        card(title: ShinnText.infoAppSection(language), icon: "app.fill") {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 54, height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.7)
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Shinn H4K")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(ShinnText.infoVersion(language)) \(appVersion)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("by Shinn Cheat")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
            }
        }
    }

    private var accountCard: some View {
        card(title: ShinnText.infoAccountSection(language), icon: "person.crop.circle.fill") {
            VStack(spacing: 10) {
                if let role {
                    infoRow(
                        label: ShinnText.infoRole(language),
                        value: language == .vietnamese ? role.displayNameVI : role.displayNameEN
                    )
                    if let username = session?.username, !username.isEmpty {
                        infoRow(label: ShinnText.usernamePlaceholder(language), value: username)
                    }
                    infoRow(label: "Key", value: "••••••")
                    if let date = session?.signedInAt {
                        infoRow(
                            label: ShinnText.infoLoginDate(language),
                            value: formattedDate(date)
                        )
                    }
                }
            }
        }
    }

    private var systemCard: some View {
        card(title: ShinnText.infoSystemSection(language), icon: "cpu") {
            VStack(spacing: 10) {
                infoRow(
                    label: ShinnText.infoDevice(language),
                    value: AppInfo.displayMachineName
                )
                infoRow(
                    label: ShinnText.infoIOS(language),
                    value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))"
                )
                infoRow(
                    label: ShinnText.infoKernelExploit(language),
                    value: exploitText,
                    valueColor: exploitColor
                )
                infoRow(
                    label: ShinnText.infoSandboxEscape(language),
                    value: sandboxText,
                    valueColor: sandboxColor
                )
            }
        }
    }

    private var exploitText: String {
        switch appState.exploitStatus {
        case .success: return ShinnText.infoActive(language)
        case .failed: return ShinnText.infoInactive(language)
        case .notStarted: return language == .vietnamese ? "Đang chờ" : "Pending"
        case .unsupported: return ShinnText.infoInactive(language)
        }
    }

    private var exploitColor: Color {
        switch appState.exploitStatus {
        case .success: return ShinnTheme.success
        case .failed, .unsupported: return ShinnTheme.danger
        case .notStarted: return ShinnTheme.warning
        }
    }

    private var sandboxText: String {
        if !KernelExploit.requiresSandboxEscape {
            return language == .vietnamese ? "Không áp dụng" : "N/A"
        }
        return KernelExploit.hasSandboxAccess()
            ? ShinnText.infoActive(language)
            : ShinnText.infoInactive(language)
    }

    private var sandboxColor: Color {
        if !KernelExploit.requiresSandboxEscape { return .white.opacity(0.4) }
        return KernelExploit.hasSandboxAccess() ? ShinnTheme.success : ShinnTheme.danger
    }

    private var contactCard: some View {
        card(title: ShinnText.infoContactSection(language), icon: "paperplane.fill") {
            VStack(spacing: 8) {
                contactLink(
                    icon: "paperplane.fill",
                    label: "Telegram: @ShinnThieuu",
                    url: "https://t.me/ShinnThieuu"
                )
                contactLink(
                    icon: "person.2.fill",
                    label: "Facebook",
                    url: "https://www.facebook.com/share/1HSmZHSdpp/?mibextid=wwXIfr"
                )
                contactLink(
                    icon: "music.note.tv.fill",
                    label: "TikTok: @shinncheat",
                    url: "https://www.tiktok.com/@shinncheat"
                )
                contactLink(
                    icon: "square.and.arrow.up.fill",
                    label: "Group Share",
                    url: "https://t.me/ShinnCheatShare"
                )
                contactLink(
                    icon: "bubble.left.and.bubble.right.fill",
                    label: "Group Chat",
                    url: "https://t.me/ShinnCheatChat"
                )
            }
        }
    }

    private var donateCard: some View {
        card(title: ShinnText.infoDonateSection(language), icon: "heart.fill") {
            VStack(alignment: .leading, spacing: 10) {
                infoRow(label: ShinnText.infoBank(language), value: "MB Bank")
                infoRow(label: ShinnText.infoAccountNumber(language), value: "104877777")
                infoRow(label: ShinnText.infoAccountHolder(language), value: "NGUYEN VU MINH HIEU")

                HStack(spacing: 8) {
                    Button {
                        UIPasteboard.general.string = "104877777"
                        copiedAccount = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            copiedAccount = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: copiedAccount ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12, weight: .semibold))
                            Text(copiedAccount
                                 ? ShinnText.copied(language)
                                 : (language == .vietnamese ? "Copy STK" : "Copy STK"))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .foregroundStyle(.white)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
                    )
                    .buttonStyle(.plain)

                    Button {
                        UIPasteboard.general.string = "Shinn H4K"
                        copiedNote = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            copiedNote = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: copiedNote ? "checkmark" : "text.badge.plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text(language == .vietnamese ? "Copy nội dung" : "Copy note")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .foregroundStyle(.white)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
                    )
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var actionCard: some View {
        card(title: language == .vietnamese ? "Hành động" : "Actions", icon: "bolt.fill") {
            VStack(spacing: 8) {
                actionButton(icon: "apple.terminal", label: ShinnText.settingsLogs(language)) {
                    showLogs = true
                }
                actionButton(icon: "doc.text", label: ShinnText.settingsLegal(language)) {