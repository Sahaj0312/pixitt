//
//  AppConfig.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import SwiftUI
import Foundation

/// Generic configurations for the app
class AppConfig {
    
    /// This is the AdMob Interstitial ad id
    /// Test App ID: ca-app-pub-3940256099942544~1458002511
    static let adMobAdId: String = "ca-app-pub-3940256099942544/4411468910"
    
    // MARK: - Generic Configurations
    static let sectionItemThumbnailSize: CGSize = .init(width: 350, height: 350)
    static let onThisDateItemSize: CGSize = .init(width: 1050, height: 550)
    static let swipeStackItemSize: CGSize = .init(width: 950, height: 1200)
    static let swipeStackOnThisDateTitle: String = "On This Date"
    static let onboardingAssets: [AssetModel] = [
        .init(id: "onboarding-1", month: .january), .init(id: "onboarding-2", month: .february)
    ]
    
    // MARK: - Settings flow items
    static let emailSupport = "support@apps4world.com"
    static let privacyURL: URL = URL(string: "https://www.google.com/")!
    static let termsAndConditionsURL: URL = URL(string: "https://www.google.com/")!
    static let yourAppURL: URL = URL(string: "https://apps.apple.com/app/idXXXXXXXXX")!
    
    // MARK: - In App Purchases
    static let premiumVersion: String = "SwipeClean.Premium"
    static let freePhotosStackCount: Int = 500
    static let premiumFeaturesList: [String] = ["Unlimited Swipes", "Remove All Ads"]
}

/// Custom colors
extension Color {
    static let backgroundColor: Color = Color("BackgroundColor")
    static let primaryTextColor: Color = Color("PrimaryTextColor")
    static let secondaryTextColor: Color = Color("SecondaryTextColor")
    static let deleteColor: Color = Color("DeleteColor")
    static let keepColor: Color = Color("KeepColor")
}

/// Full Screen flow
enum FullScreenMode: Int, Identifiable {
    case premium
    var id: Int { hashValue }
}

/// Custom tab bar items
enum CustomTabBarItem: String, CaseIterable, Identifiable {
    case discover = "Discover"
    case swipeClean = "SwipeClean"
    case photoBin = "PhotoBin"
    case settings = "Settings"
    var id: Int { hashValue }
    
    /// Tab bar icon
    var icon: String {
        switch self {
        case .discover:
            return "house.fill"
        case .swipeClean:
            return "photo.stack.fill"
        case .photoBin:
            return "trash.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}

/// Months of the year
enum CalendarMonth: String, CaseIterable, Identifiable {
    case january, february, march, april, may, june, july, august, september, october, november, december
    var id: Int { hashValue }
}
