import SwiftUI

struct HomeView: View {
    @Environment(\.shinnLanguage) private var language
    @EnvironmentObject private var appState: ShinnAppState
    @EnvironmentObject private var repositoryStore: ShinnRepositoryStore
    @EnvironmentObject private var patchStore: ShinnPatchStore
    @State private var selectedPackage: ShinnRepositoryPackage?

    private var role: ShinnRole? { appState.session?.role }

    private var visibleRepositories: [ShinnRepositorySource] {
        guard let role else { return [] }
        return repositoryStore.sources.filter { source in
            switch source.kind {
            case .shinnThieuu: return role.canAccessShinnThieuu
            case .shinnChest: return role.canAccessShinnChest
            }
        }
    }

    private var groupedCategories: [ShinnHomeCategory] {
        var result: [ShinnHomeCategory] = []
        for repo in visibleRepositories {
            let manifest = repositoryStore.manifest(for: repo)
            let packages = manifest?.packages ?? []
            var byCategory: [String: [ShinnRepositoryPackage]] = [:]
            for package in packages {
                let key = package.category ?? (language == .vietnamese ? "Khác" : "Other")
                byCategory[key, default: []].append(package)
            }
            for (category, items) in byCategory.sorted(by: { $0.key < $1.key }) {
                result.append(ShinnHomeCategory(
                    repositoryID: repo.id,
                    repositoryName: manifest?.name ?? repo.displayName,
                    category: category,
                    packages: items
                ))
            }
        }
        return result
    }

    var body: some View {
        ZStack {
            ShinnTheme.background.ignoresSafeArea()
            ShinnTheme.homeGradient.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 20) {
                    headerCard
                    if visibleRepositories.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedCategories) { group in
                            categorySection(group)
                        }
                    }
                }
                .padding(.horizontal, ShinnTheme.pageInset)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .refreshable {
                await repositoryStore.refreshAllAndWait(role: role)
            }
        }
        .navigationTitle("Shinn H4K")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                ShinnLogo(compact: true)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await repositoryStore.refreshAllAndWait(role: role) }
                } label: {
                    if repositoryStore.isRefreshing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(repositoryStore.isRefreshing)
            }
        }
        .onAppear {
            repositoryStore.loadIfNeeded(role: role)
        }
        .navigationDestination(item: $selectedPackage) { package in
            ShinnPackageDetailView(package: package)
        }
    }

    private var headerCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.8), radius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("APP")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("SHINN H4K")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.6), radius: 5)
                }
                Spacer()
            }

            Divider().overlay(Color.white.opacity(0.15))

            HStack(spacing: 10) {
                Image(systemName: "cube.box.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(language == .vietnamese
                     ? "LÀ APP VÀ REPO HOÀN TOÀN FREE"
                     : "APP AND REPO ARE COMPLETELY FREE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )

            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(language == .vietnamese
                         ? "NẾU BẠN MUA CHÚNG"
                         : "IF YOU PAID FOR THEM")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.65))
                    Text(language == .vietnamese
                         ? "BẠN ĐÃ BỊ LỪA!"
                         : "YOU'VE BEEN SCAMMED!")
                        .font(.system(size: 15, weight: .black))
                        .tracking(1)
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
            )

            Link(destination: URL(string: "https://t.me/ShinnThieuu")!) {
                HStack(spacing: 10) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Telegram: @ShinnThieuu")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.6)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ShinnTheme.cardCornerRadius, style: .continuous)
                .fill(ShinnTheme.cardBackground)
        )
        .overlay(NeonCardBorder(isHighlighted: false))
    }

    private func categorySection(_ group: ShinnHomeCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "cube.box.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.category.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                    Text(group.repositoryName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(language == .vietnamese ? "Miễn phí" : "Free")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6))
            }

            VStack(spacing: 10) {
                ForEach(group.packages) { package in
                    Button {
                        selectedPackage = package
                    } label: {
                        packageRow(package)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func packageRow(_ package: ShinnRepositoryPackage) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                if let url = package.iconURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        default:
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                } else {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 54, height: 54)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(package.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("v\(package.version)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Text(package.summary)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ShinnTheme.cardCornerRadius, style: .continuous)
                .fill(ShinnTheme.cardBackground)
        )
        .overlay(NeonCardBorder(isHighlighted: false))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "shippingbox")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text(ShinnText.homeEmpty(language))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            if let role {
                Text("Role: \(language == .vietnamese ? role.displayNameVI : role.displayNameEN)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct ShinnHomeCategory: Identifiable {
    let repositoryID: UUID
    let repositoryName: String
    let category: String
    let packages: [ShinnRepositoryPackage]

    var id: String { "\(repositoryID.uuidString)#\(category)" }
}