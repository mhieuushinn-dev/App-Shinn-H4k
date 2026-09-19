import SwiftUI
import UIKit

enum ShinnTab: Int, CaseIterable, Identifiable {
    case home
    case sources
    case installed
    case info
    case settings

    var id: Int { rawValue }

    func title(_ lang: ShinnLanguage) -> String {
        switch self {
        case .home: return ShinnText.tabHome(lang)
        case .sources: return ShinnText.tabSources(lang)
        case .installed: return ShinnText.tabInstalled(lang)
        case .info: return ShinnText.tabInfo(lang)
        case .settings: return ShinnText.tabSettings(lang)
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .sources: return "shippingbox.fill"
        case .installed: return "tray.full.fill"
        case .info: return "info.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct RootView: View {
    @Environment(\.shinnLanguage) private var language
    @EnvironmentObject private var appState: ShinnAppState
    @EnvironmentObject private var repositoryStore: ShinnRepositoryStore
    @EnvironmentObject private var patchStore: ShinnPatchStore
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label(ShinnTab.home.title(language), systemImage: ShinnTab.home.systemImage)
            }
            .tag(ShinnTab.home.rawValue)

            NavigationStack {
                SourcesView()
            }
            .tabItem {
                Label(ShinnTab.sources.title(language), systemImage: ShinnTab.sources.systemImage)
            }
            .tag(ShinnTab.sources.rawValue)

            NavigationStack {
                InstalledView()
            }
            .tabItem {
                Label(ShinnTab.installed.title(language), systemImage: ShinnTab.installed.systemImage)
            }
            .tag(ShinnTab.installed.rawValue)

            NavigationStack {
                InfoView()
            }
            .tabItem {
                Label(ShinnTab.info.title(language), systemImage: ShinnTab.info.systemImage)
            }
            .tag(ShinnTab.info.rawValue)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(ShinnTab.settings.title(language), systemImage: ShinnTab.settings.systemImage)
            }
            .tag(ShinnTab.settings.rawValue)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
        .onAppear {
            applyDarkAppearance()
        }
    }

    private func applyDarkAppearance() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 1)
        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.45)
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.45)
        ]
        tabAppearance.stackedLayoutAppearance.selected.iconColor = .white
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 1)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }
}