import SwiftUI

private enum ShinnOnboardingStep: Int, CaseIterable {
    case legal = 0
    case risk
    case responsibility
    case language

    var next: ShinnOnboardingStep? { Self(rawValue: rawValue + 1) }
    var prev: ShinnOnboardingStep? { Self(rawValue: rawValue - 1) }
}

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ShinnLanguage.storageKey)
    private var languageCode = ShinnLanguage.vietnamese.rawValue
    @State private var step: ShinnOnboardingStep = .legal
    @State private var agreed = false
    @State private var navDirection: Int = 1
    var onComplete: () -> Void

    private var language: ShinnLanguage {
        ShinnLanguage(rawValue: languageCode) ?? .vietnamese
    }

    private var motion: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.24)
    }

    var body: some View {
        ZStack {
            ShinnTheme.background.ignoresSafeArea()
            ShinnTheme.homeGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                pageContent
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            controls
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(ShinnOnboardingStep.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue
                              ? Color.white
                              : Color.white.opacity(0.2))
                        .frame(height: 3)
                        .frame(maxWidth: s == step ? 28 : 18)
                        .animation(motion, value: step)
                }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 20)

            Text(stepLabel)
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var stepLabel: String {
        let total = ShinnOnboardingStep.allCases.count
        return language == .vietnamese
            ? "BƯỚC \(step.rawValue + 1) / \(total)"
            : "STEP \(step.rawValue + 1) / \(total)"
    }

    @ViewBuilder
    private var pageContent: some View {
        ZStack {
            ForEach(ShinnOnboardingStep.allCases, id: \.rawValue) { s in
                if s == step {
                    ScrollView(.vertical, showsIndicators: false) {
                        page(for: s)
                            .frame(maxWidth: 560)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 22)
                            .padding(.top, 12)
                            .padding(.bottom, 28)
                    }
                    .transition(pageTransition)
                    .id(s.rawValue)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let forward = navDirection >= 0
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    @ViewBuilder
    private func page(for s: ShinnOnboardingStep) -> some View {
        switch s {
        case .legal: legalPage
        case .risk: riskPage
        case .responsibility: responsibilityPage
        case .language: languagePage
        }
    }

    private var legalPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            iconHeader(system: "shield.lefthalf.filled", color: .white)
            titleBlock(
                title: ShinnText.onboardingLegalTitle(language),
                subtitle: language == .vietnamese
                    ? "Vui lòng đọc kỹ trước khi tiếp tục"
                    : "Please read carefully before continuing"
            )
            termsBox(ShinnText.onboardingLegalBody(language))
            agreementToggle
            Spacer(minLength: 0)
        }
    }

    private var riskPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            iconHeader(system: "exclamationmark.triangle.fill", color: ShinnTheme.warning)
            titleBlock(
                title: ShinnText.onboardingRiskTitle(language),
                subtitle: language == .vietnamese
                    ? "Bạn tự chịu mọi rủi ro phát sinh"
                    : "You assume all arising risks"
            )
            termsBox(ShinnText.onboardingRiskBody(language))
            agreementToggle
            Spacer(minLength: 0)
        }
    }

    private var responsibilityPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            iconHeader(system: "person.badge.shield.checkmark.fill", color: ShinnTheme.success)
            titleBlock(
                title: ShinnText.onboardingResponsibilityTitle(language),
                subtitle: language == .vietnamese
                    ? "Xác nhận lần cuối"
                    : "Final confirmation"
            )
            termsBox(ShinnText.onboardingResponsibilityBody(language))
            agreementToggle
            Spacer(minLength: 0)
        }
    }

    private var languagePage: some View {
        VStack(alignment: .leading, spacing: 20) {
            iconHeader(system: "globe", color: .white)
            titleBlock(
                title: ShinnText.onboardingLanguageTitle(language),
                subtitle: language == .vietnamese
                    ? "Có thể thay đổi trong Cài đặt"
                    : "You can change this in Settings"
            )

            VStack(spacing: 12) {
                ForEach(ShinnLanguage.allCases) { option in
                    let selected = languageCode == option.rawValue
                    Button {
                        languageCode = option.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            Text(option.displayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(selected ? .white : Color.white.opacity(0.35))
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(ShinnTheme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    selected ? Color.white.opacity(0.9) : Color.white.opacity(0.15),
                                    lineWidth: selected ? 1 : 0.6
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func iconHeader(system: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                )
            Image(systemName: system)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 68, height: 68)
    }

    private func titleBlock(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(ShinnTheme.secondaryText)
        }
    }

    private func termsBox(_ body: String) -> some View {
        Text(body)
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.8))
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ShinnTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
            )
    }

    private var agreementToggle: some View {
        Button {
            agreed.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: agreed ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(agreed ? .white : Color.white.opacity(0.4))
                Text(ShinnText.onboardingCheckbox(language))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(agreed ? 1 : 0.75))
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if step != .legal {
                    Button {
                        navDirection = -1
                        if let prev = step.prev {
                            withAnimation(motion) { step = prev }
                            agreed = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text(ShinnText.back(language))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(.white)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: ShinnTheme.buttonCornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ShinnTheme.buttonCornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.6)
                    )
                    .buttonStyle(.plain)
                }

                Button(action: advance) {
                    HStack(spacing: 6) {
                        Text(step == .language
                             ? ShinnText.finish(language)
                             : ShinnText.next(language))
                            .font(.system(size: 14, weight: .bold))
                        if step != .language {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(canAdvance ? Color.black : Color.white.opacity(0.35))
                }
                .background(
                    RoundedRectangle(cornerRadius: ShinnTheme.buttonCornerRadius, style: .continuous)
                        .fill(canAdvance ? Color.white : Color.white.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ShinnTheme.buttonCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(canAdvance ? 0.9 : 0.2), lineWidth: 0.8)
                )
                .buttonStyle(.plain)
                .disabled(!canAdvance)
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 22)

            if step != .language {
                Button(action: refuseAndExit) {
                    Text(ShinnText.onboardingRefuse(language))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    private var canAdvance: Bool {
        if step == .language { return true }
        return agreed
    }

    private func advance() {
        navDirection = 1
        if let next = step.next {
            withAnimation(motion) { step = next }
            agreed = false
        } else {
            onComplete()
        }
    }

    private func refuseAndExit() {
        exit(0)
    }
}