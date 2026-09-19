import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject var appState: ShinnAppState
    @Environment(\.shinnLanguage) private var language

    @State private var username = ""
    @State private var key = ""
    @State private var showFailureAlert = false
    @State private var failureMessage = ""

    private var requiresUsernameField: Bool {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized == "080109" || normalized == "00001"
    }

    private var canSubmit: Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return false }
        if requiresUsernameField {
            return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    var body: some View {
        ZStack {
            ShinnTheme.background.ignoresSafeArea()
            ShinnTheme.homeGradient.ignoresSafeArea()

            decorativeGlow
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                ShinnLogo()
                    .padding(.bottom, 8)
                Text("GAMING CENTER")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(3.5)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 36)

                loginCard
                    .padding(.horizontal, 22)

                Spacer(minLength: 20)

                Text("v\(appVersion) · \(AppInfo.displayMachineName)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 24)
            }
        }
        .alert(ShinnText.keyWrongTitle(language), isPresented: $showFailureAlert) {
            Button(ShinnText.ok(language)) {
                exit(0)
            }
        } message: {
            Text(failureMessage)
        }
    }

    private var decorativeGlow: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.12), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .position(x: size.width * 0.9, y: size.height * 0.1)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.08), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .frame(width: 360, height: 360)
                    .position(x: size.width * 0.1, y: size.height * 0.9)
            }
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ShinnText.loginTitle(language))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text(ShinnText.loginSubtitle(language))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(ShinnTheme.secondaryText)
            }

            if requiresUsernameField {
                fieldLabel(ShinnText.usernamePlaceholder(language))
                inputField(
                    text: $username,
                    placeholder: ShinnText.usernamePlaceholder(language),
                    isSecure: false,
                    icon: "person.fill"
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            fieldLabel(ShinnText.keyPlaceholder(language))
            inputField(
                text: $key,
                placeholder: ShinnText.keyPlaceholder(language),
                isSecure: true,
                icon: "key.fill"
            )

            Button(action: submit) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(ShinnText.signInButton(language))
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1.5)
                }
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(canSubmit ? Color.black : Color.white.opacity(0.4))
                .background(
                    RoundedRectangle(cornerRadius: ShinnTheme.buttonCornerRadius, style: .continuous)
                        .fill(canSubmit ? Color.white : Color.white.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ShinnTheme.buttonCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(canSubmit ? 0.9 : 0.2), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .animation(.easeInOut(duration: 0.18), value: canSubmit)

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                Text(language == .vietnamese
                     ? "Nhập sai key sẽ tự động thoát ứng dụng"
                     : "Entering an invalid key will exit the app")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.white.opacity(0.35))
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: ShinnTheme.cardCornerRadius, style: .continuous)
                .fill(ShinnTheme.cardBackground)
        )
        .overlay(NeonCardBorder(isHighlighted: true))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.5))
    }

    private func inputField(
        text: Binding<String>,
        placeholder: String,
        isSecure: Bool,
        icon: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 18)

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .onSubmit { if canSubmit { submit() } }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.6)
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private func submit() {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let role = ShinnAuthService.resolveRole(
            rawKey: normalizedKey,
            username: requiresUsernameField ? normalizedUsername : nil
        ) else {
            failureMessage = ShinnText.keyWrongMessage(language)
            showFailureAlert = true
            return
        }

        appState.signIn(
            role: role,
            username: role.requiresUsername ? normalizedUsername : nil,
            rawKey: normalizedKey
        )
    }
}