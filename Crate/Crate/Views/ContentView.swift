import SwiftUI
import SwiftData

struct ContentView: View {
    private enum AppTab: Hashable {
        case shelf, wishlist, showcase
    }

    @AppStorage("pendingRecordDeepLink") private var pendingRecordDeepLink = ""
    @AppStorage("pendingOpenWishlist") private var pendingOpenWishlist = false
    @AppStorage("appThemeMode") private var appThemeMode = "system"
    @State private var selectedTab: AppTab = .shelf

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
        TabView(selection: $selectedTab) {
            NavigationStack { ShelfView() }
                .tabItem { Label(String(localized: "shelf.tab"), systemImage: "tray.full") }
                .tag(AppTab.shelf)

            NavigationStack { WishlistView() }
                .tabItem { Label(String(localized: "wishlist.tab"), systemImage: "heart") }
                .tag(AppTab.wishlist)

            NavigationStack { ShowcaseView() }
                .tabItem { Label(String(localized: "showcase.tab"), systemImage: "circle.dotted") }
                .tag(AppTab.showcase)
        }
        .tint(AppTheme.gold)
        .preferredColorScheme(preferredScheme)
        .onAppear {
            applyPendingTabOpen()
        }
        .onChange(of: pendingOpenWishlist) {
            applyPendingTabOpen()
        }
        .onOpenURL { url in
            guard url.scheme == "crate" else { return }
            if url.host == "wishlist" {
                selectedTab = .wishlist
            } else if url.host == "record" {
                selectedTab = .shelf
                pendingRecordDeepLink = url.pathComponents.dropFirst().first ?? ""
            }
        }
    }

    private func applyPendingTabOpen() {
        guard pendingOpenWishlist else { return }
        selectedTab = .wishlist
        pendingOpenWishlist = false
    }

    private var preferredScheme: ColorScheme? {
        switch appThemeMode {
        case "dark": .dark
        case "light": .light
        default: nil
        }
    }
}
