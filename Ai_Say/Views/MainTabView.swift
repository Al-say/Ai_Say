import SwiftUI

enum MainTab: String, CaseIterable {
    case home, growth, explore, profile

    var title: String {
        switch self {
        case .home: "Home"
        case .growth: "Growth"
        case .explore: "Explore"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .growth: "chart.line.uptrend.xyaxis"
        case .explore: "magnifyingglass"
        case .profile: "person"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: MainTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(MainTab.home)
                    .tabItem {
                        Label(MainTab.home.title, systemImage: MainTab.home.icon)
                    }

                GrowthView()
                    .tag(MainTab.growth)
                    .tabItem {
                        Label(MainTab.growth.title, systemImage: MainTab.growth.icon)
                    }

                ExploreView()
                    .tag(MainTab.explore)
                    .tabItem {
                        Label(MainTab.explore.title, systemImage: MainTab.explore.icon)
                    }

                ProfileView()
                    .tag(MainTab.profile)
                    .tabItem {
                        Label(MainTab.profile.title, systemImage: MainTab.profile.icon)
                    }
            }
            .toolbar(.hidden, for: .tabBar)

            M3BottomNavigationBar(selection: $selectedTab)
                .ignoresSafeArea(.keyboard)
        }
    }
}