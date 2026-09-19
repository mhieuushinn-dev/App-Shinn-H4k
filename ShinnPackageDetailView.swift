import SwiftUI

struct ShinnPackageDetailView: View {
    @Environment(\.shinnLanguage) private var language
    @EnvironmentObject private var appState: ShinnAppState
    @EnvironmentObject private var repositoryStore: ShinnRepositoryStore
    @EnvironmentObject private var patchStore: ShinnPatchStore
    @Environment(\.dismiss) private var dismiss
    @State private var showApplyConfirm = false

    let package: ShinnRepositoryPackage

    private var role: ShinnRole? { appState.session?.role }

    private var compatibility: ShinnPackageCompatibility {
        ShinnCompatibilityEvaluator.evaluate(
            package.supportedOS,
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    private var isDownloading: Bool {
        repositoryStore.downloadingPackageIDs.contains(package.id)
    }

    var body: some View {
        ZStack {
            ShinnTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    descriptionCard
                    infoCard
                    actionCard
                }
                .padding(.horizontal, ShinnTheme.pageInset)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(package.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            language == .vietnamese ? "Áp dụng patch?" : "Apply patch?",
            isPresented: $showApplyConfirm
        ) {
            Button(ShinnText.cancel(language), role: .cancel) {
                // đóng alert
            }
            Button(ShinnText.patchApply(language), role: .destructive) {
                Task {
                    await repositoryStore.download(
                        package,
                        role: role,
                        patchStore: patchStore
                    )
                    dismiss()
                }
            }
        } message: {
            Text(ShinnText.patchApplyConfirm(package.name, lang: language))
        }
    }

    // MARK: - Header
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                iconView
                VStack(alignment: .leading, spacing: 4) {
                    Text(package.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text(package.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        badge(text: "v\(package.version)")
                        if let category = package.category {
                            badge(text: category)
                        }
                        if package.isPrivate {
                            badge(text: language == .vietnamese ? "Riêng tư" : "Private")
                        }
                    }
                }
            }

            Divider().overlay(Color.white.opacity(0.1))

            HStack(spacing: 8) {
                Image(systemName: compatibilityIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(compatibilityColor)
                Text(compatibilityText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(compatibilityColor)
                Spacer()
                Text(package.repositoryName)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ShinnTheme.cardCornerRadius, style: .continuous)
                .fill(ShinnTheme.cardBackground)
        )
        .overlay(NeonCardBorder(isHighlighted: true))
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
            if let url = package.iconURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    default:
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            } else {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(width: 72, height: 72)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.7)
        )
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.1)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
    }

    private var compatibilityIcon: String {
        switch compatibility {
        case .compatible: return "checkmark.seal.fill"
        case .incompatible: return "xmark.seal.fill"
        case .unknown: return "questionmark.seal.fill"
        }
    }

    private var compatibilityColor: Color {
        switch compatibility {
        case .compatible: return ShinnTheme.success
        case .incompatible: return ShinnTheme.danger
        case .unknown: return ShinnTheme.warning
        }
    }

    private var compatibilityText: String {
        switch compatibility {
        case .compatible:
            return language == .vietnamese ? "Tương thích" : "Compatible"
        case .incompatible:
            return language == .vietnamese ? "Không tương thích" : "Incompatible"
        case .unknown:
            return language == .vietnamese ? "Chưa xác định" : "Unknown"
        }
    }

    // MARK: - Description
    private var descriptionCard: some View {
        card(title: language == .vietnamese ? "Mô tả" : "Description") {
            Text(package.details ?? package.summary)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.75))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Info
    private var infoCard: some View {
        card(title: language == .vietnamese ? "Thông tin" : "Information") {
            VStack(spacing: 8) {
                infoRow(label: "ID", value: package.identifier)
                infoRow(label: language == .vietnamese ? "Tác giả" : "Author", value: package.author)
                infoRow(label: language == .vietnamese ? "Phiên bản" : "Version", value: package.version)
                infoRow(label: language == .vietnamese ? "Nguồn" : "Source", value: package.repositoryName)
                if let size = package.expectedSize {
                    infoRow(
                        label: language == .vietnamese ? "Kích thước" : "Size",
                        value: ByteCountFormatter.string(
                            fromByteCount: Int64(size),
                            countStyle: .file
                        )
                    )
                }
                if let sha = package.sha256 {
                    infoRow(label: "SHA-256", value: String(sha.prefix(16)) + "…")
                }
                if let date = package.publishedAt {
                    infoRow(
                        label: language == .vietnamese ? "Phát hành" : "Published",
                        value: formattedDate(date)
                    )
                }
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = language.locale
        return f.string(from: date)
    }

    // MARK: - Action
    private var actionCard: some View {
        VStack(spacing: 10) {
            if role?.canDownloadPackage == true {
                if compatibility == .incompatible {
                    Text(language == .vietnamese
                         ? "Gói không hỗ trợ iOS hiện tại"
                         : "Package doesn't support current iOS")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ShinnTheme.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                } else {
                    Button {
                        showApplyConfirm = true
                    } label: {
                        HStack(spacing: 8) {
                            if isDownloading {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text(isDownloading
                                 ? (language == .vietnamese ? "ĐANG TẢI" : "DOWNLOADING")
                                 : (language == .vietnamese ? "TẢI VÀ ÁP DỤNG" : "DOWNLOAD & APPLY"))
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(.black)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isDownloading)
                }
            } else {
                Text(ShinnText.patchNoPermission(language))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ShinnTheme.warning)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
            }
        }
    }

    // MARK: - Reusable card
    private func card<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ShinnTheme.cardCornerRadius, style: .continuous)
                .fill(ShinnTheme.cardBackground)
        )
        .overlay(NeonCardBorder(isHighlighted: false))
    }
}