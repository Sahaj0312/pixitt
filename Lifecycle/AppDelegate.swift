//
//  AppDelegate.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import UIKit
import Foundation
import PurchaseKit
import GoogleMobileAds
import AppTrackingTransparency

/// App Delegate file in SwiftUI
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        PKManager.loadProducts(identifiers: [AppConfig.premiumVersion])
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in self.requestIDFA() }
        return true
    }
    
    /// Display the App Tracking Transparency authorization request for accessing the IDFA
    func requestIDFA() {
        DispatchQueue.main.async {
            ATTrackingManager.requestTrackingAuthorization { _ in
                GADMobileAds.sharedInstance().start(completionHandler: nil)
            }
        }
    }
}

// MARK: - Google AdMob Interstitial - Support class
class Interstitial: NSObject, GADFullScreenContentDelegate {
    var isPremiumUser: Bool = UserDefaults.standard.bool(forKey: AppConfig.premiumVersion)
    private var interstitial: GADInterstitialAd?
    static var shared: Interstitial = Interstitial()

    /// Default initializer of interstitial class
    override init() {
        super.init()
        loadInterstitial()
    }

    /// Request AdMob Interstitial ads
    func loadInterstitial() {
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: AppConfig.adMobAdId, request: request, completionHandler: { [self] ad, error in
            if ad != nil { interstitial = ad }
            interstitial?.fullScreenContentDelegate = self
        })
    }

    func showInterstitialAds() {
        if self.interstitial != nil, !isPremiumUser {
            guard let root = rootController else { return }
            self.interstitial?.present(fromRootViewController: root)
        }
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        loadInterstitial()
    }
}
