import SwiftUI

enum MainTab: Int, CaseIterable {
    case home = 0
    case growth = 1
    case explore = 2
    case profile = 3

    var title: String {
        switch self {
        case .home: return "主页"
        case .growth: return "成长"
        case .explore: return "探索"
        case .profile: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .growth: return "chart.line.uptrend.xyaxis"
        case .explore: return "safari"
        case .profile: return "person.crop.circle"
        }
    }
}

struct MainTabView: View {
    @StateObject private var router = AppRouter()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $router.selectedTab) {
                HomeView()
                    .tag(MainTab.home)

                GrowthView()
                    .tag(MainTab.growth)

                ExploreView()
                    .tag(MainTab.explore)

                ProfileView()
                    .tag(MainTab.profile)
            }
            // 隐藏系统 TabBar（让自定义底栏接管）
            .toolbar(.hidden, for: .tabBar)

            M3BottomNavigationBar(selection: $router.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .environmentObject(router)
    }
}