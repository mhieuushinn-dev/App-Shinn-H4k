import SwiftUI

struct InstalledView: View {
    @Environment(\.shinnLanguage) private var language
    @EnvironmentObject private var appState: ShinnAppState
    @EnvironmentObject private var patchStore: ShinnPatchStore
    @State private var deleteTarget: ShinnInstalledPatch?

    private var role: ShinnRole? { appState.session?.role }

    var body: some View {
        ZStack {
            ShinnTheme.background.ignoresSafeArea()

            if patchStore.installed.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(patchStore.installed) { item in
                        installedRow(item)
                            .listRowBackground(ShinnTheme.cardBackground)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(ShinnText.tabInstalled(language))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            language == .vietnamese ? "Xoá patch?" : "Delete patch?",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            presenting: deleteTarget
        ) { item in
            Button(ShinnText.cancel(language), role: .cancel) { deleteTarget = nil }
            Button(ShinnText.delete(language), role: .destructive) {
                patchStore.delete(item)
                deleteTarget = nil
            }
        } message: { item in
            Text(item.name)
        }
    }

    private func installedRow(_ item: ShinnInstalledPatch) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    Text(item.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(item.bundleID)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
                Spacer()
                if role?.canDeleteInstalled == true {
                    Button {
                        deleteTarget = item
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

            HStack(spacing: 6) {
                Circle()
                    .fill(item.isApplied ? ShinnTheme.success : .white.opacity(0.35))
                    .frame(width: 6, height: 6)
                Text(item.isApplied
                     ? (language == .vietnamese ? "Đang áp dụng" : "Active")
                     : (language == .vietnamese ? "Chưa áp dụng" : "Inactive"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
            }

            if role?.canApplyPatch == true {
                HStack(spacing: 8) {
                    Button {
                        Task { await patchStore.apply(item) }
                    } label: {
                        Text(ShinnText.patchApply(language))
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .foregroundStyle(.black)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(item.isApplied)

                    Button {
                        Task { await patchStore.restore(item) }
                    } label: {
                        Text(ShinnText.patchRestore(language))
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.6)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!item.isApplied)
                }
            } else {
                Text(ShinnText.patchNoPermission(language))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: ShinnTheme.cardCornerRadius, style: .continuous)
                .fill(ShinnTheme.cardBackground)
        )
        .overlay(NeonCardBorder(isHighlighted: false))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text(language == .vietnamese
                 ? "Chưa có patch nào được cài"
                 : "No installed patches yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}