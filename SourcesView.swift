import SwiftUI

struct SourcesView: View {
    @Environment(\.shinnLanguage) private var language
    @EnvironmentObject private var appState: ShinnAppState
    @EnvironmentObject private var repositoryStore: ShinnRepositoryStore
    @State private var showDeleteConfirm: ShinnRepositorySource?

    private var role: ShinnRole? { appState.session?.role }

    private var visibleSources: [ShinnRepositorySource] {
        guard let role else { return [] }
        return repositoryStore.sources.filter { source in
            switch source.kind {
            case .shinnThieuu: return role.canAccessShinnThieuu
            case .shinnChest: return role.canAccessShinnChest
            }
        }
    }

    var body: some View {
        ZStack {
            ShinnTheme.background.ignoresSafeArea()

            List {
                ForEach(visibleSources) { source in
                    sourceRow(source)
                        .listRowBackground(ShinnTheme.cardBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(ShinnText.sourcesTitle(language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
        .alert(
            language == .vietnamese ? "Xoá nguồn?" : "Delete source?",
            isPresented: Binding(
                get: { showDeleteConfirm != nil },
                set: { if !$0 { showDeleteConfirm = nil } }
            ),
            presenting: showDeleteConfirm
        ) { source in
            Button(ShinnText.cancel(language), role: .cancel) {
                showDeleteConfirm = nil
            }
            Button(ShinnText.delete(language), role: .destructive) {
                repositoryStore.removeSource(source)
                showDeleteConfirm = nil
            }
        } message: { source in
            Text(source.manifestURL.absoluteString)
        }
    }

    private func sourceRow(_ source: ShinnRepositorySource) -> some View {
        let manifest = repositoryStore.manifest(for: source)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(manifest?.name ?? source.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(manifest?.identifier ?? "—")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
                Spacer()
                if role?.canDeleteSources == true {
                    Button {
                        showDeleteConfirm = source
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ShinnTheme.danger)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(source.manifestURL.absoluteString)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .lineLimit(2)
                .truncationMode(.middle)

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor(for: source))
                    .frame(width: 6, height: 6)
                Text(statusText(for: source))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(ShinnText.homePackageCount(manifest?.packages.count ?? 0, lang: language))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: ShinnTheme.cardCornerRadius, style: .continuous)
                .fill(ShinnTheme.cardBackground)
        )
        .overlay(NeonCardBorder(isHighlighted: false))
    }

    private func statusColor(for source: ShinnRepositorySource) -> Color {
        switch repositoryStore.state(for: source.id) {
        case .loaded: return ShinnTheme.success
        case .loading: return ShinnTheme.warning
        case .failed: return ShinnTheme.danger
        case .idle: return .white.opacity(0.35)
        }
    }

    private func statusText(for source: ShinnRepositorySource) -> String {
        switch repositoryStore.state(for: source.id) {
        case .loaded: return language == .vietnamese ? "Đã tải" : "Loaded"
        case .loading: return language == .vietnamese ? "Đang tải" : "Loading"
        case .failed: return language == .vietnamese ? "Lỗi" : "Failed"
        case .idle: return language == .vietnamese ? "Chưa tải" : "Not loaded"
        }
    }
}