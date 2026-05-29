import SwiftUI
import SwiftData

struct ContentView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.bgDeep)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppTheme.inkFaint)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.inkFaint)]
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppTheme.gold)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.gold)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(AppTheme.bg)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.ink)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    var body: some View {
        TabView {
            NavigationStack { ShelfView() }
                .tabItem { Label("Полка", systemImage: "tray.full") }

            NavigationStack { WishlistView() }
                .tabItem { Label("Вишлист", systemImage: "heart") }

            NavigationStack { ShowcaseView() }
                .tabItem { Label("Витрина", systemImage: "circle.dotted") }
        }
        .tint(AppTheme.gold)
    }
}
