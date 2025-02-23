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
                
                // Show swipe count for all tabs except when in photo bin with items
                if manager.selectedTab == .photoBin && manager.removeStackAssets.count > 0 {
                    SelectionButton()
                } else {
                    SwipeCountView()
                }
            }.padding()
            Spacer()
        }
    }
    
    /// Selection button for photo bin
    private func SelectionButton() -> some View {
        Button(action: {
            NotificationCenter.default.post(name: .init("ToggleSelectAll"), object: nil)
        }) {
            Text(manager.selectedAssets.count == manager.removeStackAssets.count ? "Deselect All" : "Select All")
                .padding(5)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .foregroundStyle(Color.blue)
                )
                .foregroundStyle(.white)
                .font(.system(size: 15, weight: .semibold))
        }
    }
    
    /// Swipe count indicator view
    private func SwipeCountView() -> some View {
        let remainingSwipes = AppConfig.freePhotosStackCount - manager.freePhotosStackCount
        return HStack(spacing: 4) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 14))
            Text(manager.isPremiumUser ? "∞" : "\(remainingSwipes)")
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(Color.blue)
        )
        .foregroundStyle(.white)
    }
    
    /// Custom tab bar item flow
    private func TabBarItemFlow(type: CustomTabBarItem) -> some View {
        ZStack {
            CustomHeaderView
            let topPadding: Double = 65.0
            switch type {
            case .discover: HomeTabView().padding(.top, topPadding)
            case .swipePhotos: SwipeTabView().padding(.top, topPadding)
            case .photoBin: PhotoBinTabView().padding(.top, topPadding)
            case .settings: SettingsTabView().padding(.top, topPadding)
            }
        }
        .background(Color.backgroundColor)
        .environmentObject(manager).tag(type).tabItem {
            Label(type.rawValue, systemImage: type.icon)
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ToggleSelectAll"))) { _ in
            if manager.selectedAssets.count == manager.removeStackAssets.count {
                manager.selectedAssets.removeAll()
            } else {
                manager.selectedAssets = Set(manager.removeStackAssets.map { $0.id })
            }
        }
    }
    
    /// Premium flow view
    private var PremiumView: some View {
        RevenueCatPaywallView()
            .environmentObject(manager)
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
