//
//  DashboardContentView.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import SwiftUI

/// Main dashboard for the app
struct DashboardContentView: View {
    
    @EnvironmentObject var manager: DataManager
    
    // MARK: - Main rendering function
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            TabView(selection: $manager.selectedTab) {
                ForEach(CustomTabBarItem.allCases) { tab in
                    TabBarItemFlow(type: tab)
                }
            }
            
            /// Show image processing overlay
            if manager.didProcessAssets == false {
                OverlayLoadingView()
            }
        }
        /// Full screen flow presentation
        .fullScreenCover(item: $manager.fullScreenMode) { type in
            switch type {
            case .premium: PremiumView
            }
        }
    }
    
    /// Custom header view
    private var CustomHeaderView: some View {
        VStack {
            HStack {
                Text(manager.selectedTab.rawValue)
                    .font(.system(size: 33, weight: .bold, design: .rounded))
                Spacer()
                if manager.selectedTab == .photoBin,
                    manager.removeStackAssets.count > 0 {
                    Button { manager.emptyPhotoBin() } label: {
                        Text("Delete").padding(5).padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .foregroundStyle(Color.red)
                            )
                            .foregroundStyle(.white)
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }.padding()
            Spacer()
        }
    }
    
    /// Custom tab bar item flow
    private func TabBarItemFlow(type: CustomTabBarItem) -> some View {
        ZStack {
            CustomHeaderView
            let topPadding: Double = 65.0
            switch type {
            case .discover: HomeTabView().padding(.top, topPadding)
            case .swipeClean: SwipeTabView().padding(.top, topPadding)
            case .photoBin: PhotoBinTabView().padding(.top, topPadding)
            case .settings: SettingsTabView().padding(.top, topPadding)
            }
        }
        .background(Color.backgroundColor)
        .environmentObject(manager).tag(type).tabItem {
            Label(type.rawValue, systemImage: type.icon)
        }
    }
    
    /// Premium flow view
    private var PremiumView: some View {
        PremiumContentView(title: "Premium Version", subtitle: "Unlock All Features", features: AppConfig.premiumFeaturesList, productIds: [AppConfig.premiumVersion]) {
            manager.fullScreenMode = nil
        } completion: { _, status, _ in
            DispatchQueue.main.async {
                if status == .success || status == .restored {
                    manager.isPremiumUser = true
                    Interstitial.shared.isPremiumUser = true
                }
                manager.fullScreenMode = nil
            }
        }
    }
}

// MARK: - Preview UI
struct DashboardContentView_Previews: PreviewProvider {
    static var previews: some View {
        let manager = DataManager()
        manager.didGrantPermissions = true
        manager.didProcessAssets = true
        return DashboardContentView().environmentObject(manager)
    }
}
