//
//  SettingsTabView.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import SwiftUI
import StoreKit
import MessageUI

/// Shows the settings for the app
struct SettingsTabView: View {
    
    @EnvironmentObject var manager: DataManager
    @State private var restoringPurchases: Bool = false
    
    // MARK: - Main rendering function
    var body: some View {
        ScrollView(.vertical) {
            VStack {
                InAppPurchasesPromoBannerView
                CustomHeader(title: "In-App Purchases")
                InAppPurchasesView
                CustomHeader(title: "Spread the Word")
                RatingShareView
                CustomHeader(title: "Support & Privacy")
                PrivacySupportView
            }.padding(.horizontal)
            Spacer(minLength: 20)
        }
    }
    
    /// Create custom header view
    private func CustomHeader(title: String) -> some View {
        HStack {
            Text(title).font(.system(size: 15, weight: .medium))
                .foregroundColor(.primaryTextColor).padding(.horizontal, 10)
            Spacer()
        }
    }

    /// Custom settings item
    private func SettingsItem(title: String, icon: String, action: @escaping() -> Void) -> some View {
        Button(action: {
            action()
        }, label: {
            HStack {
                Image(systemName: icon).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22, alignment: .center)
                Text(title).font(.system(size: 18))
                Spacer()
                Image(systemName: "chevron.right")
            }.padding().foregroundColor(.primaryTextColor)
        })
    }

    // MARK: - In App Purchases
    private var InAppPurchasesView: some View {
        VStack {
            SettingsItem(title: "Upgrade Premium", icon: "crown") {
                manager.fullScreenMode = .premium
            }
            Color.secondaryTextColor.frame(height: 1).opacity(0.3).padding(.horizontal)
            SettingsItem(title: restoringPurchases ? "Please wait..." : "Restore Purchases", icon: "arrow.clockwise") {
                restoringPurchases = true
                Task {
                    do {
                        let customerInfo = try await RevenueCatConfig.shared.restorePurchases()
                        if customerInfo.entitlements[RevenueCatConfig.entitlementIdentifier]?.isActive == true {
                            manager.isPremiumUser = true
                        }
                    } catch {
                        // Handle error if needed
                    }
                    restoringPurchases = false
                }
            }
        }.modifier(SectionBackgroundView(bottomPadding: 30))
    }
    
    private var InAppPurchasesPromoBannerView: some View {
        ZStack {
            if manager.isPremiumUser == false {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Premium Version").bold().font(.system(size: 20))
                        ForEach(AppConfig.premiumFeaturesList, id: \.self) { feature in
                            Text("- \(feature)").font(.system(size: 15)).opacity(0.7)
                        }
                    }
                    Spacer()
                    Image(systemName: "crown.fill").font(.system(size: 45))
                }
                .foregroundColor(.white)
                .padding(.horizontal).padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [.deleteColor, .keepColor], startPoint: .topTrailing, endPoint: .bottomLeading).cornerRadius(12)
                ).padding(.bottom)
            }
        }
    }

    // MARK: - Rating and Share
    private var RatingShareView: some View {
        VStack {
            SettingsItem(title: "Rate App", icon: "star") {
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                }
            }
            Color.secondaryTextColor.frame(height: 1).opacity(0.3).padding(.horizontal)
            SettingsItem(title: "Share App", icon: "square.and.arrow.up") {
                let shareController = UIActivityViewController(activityItems: [AppConfig.yourAppURL], applicationActivities: nil)
                rootController?.present(shareController, animated: true, completion: nil)
            }
        }.modifier(SectionBackgroundView(bottomPadding: 30))
    }

    // MARK: - Support & Privacy
    private var PrivacySupportView: some View {
        VStack {
            SettingsItem(title: "E-Mail us", icon: "envelope.badge") {
                EmailPresenter.shared.present()
            }
            Color.secondaryTextColor.frame(height: 1).opacity(0.3).padding(.horizontal)
            SettingsItem(title: "Privacy Policy", icon: "hand.raised") {
                UIApplication.shared.open(AppConfig.privacyURL, options: [:], completionHandler: nil)
            }
            Color.secondaryTextColor.frame(height: 1).opacity(0.3).padding(.horizontal)
            SettingsItem(title: "Terms of Use", icon: "doc.text") {
                UIApplication.shared.open(AppConfig.termsAndConditionsURL, options: [:], completionHandler: nil)
            }
        }.modifier(SectionBackgroundView())
    }
}

// MARK: - Preview UI
#Preview {
    ZStack {
        Color.backgroundColor.ignoresSafeArea()
        SettingsTabView().environmentObject(DataManager())
    }
}

// MARK: - Mail presenter for SwiftUI
class EmailPresenter: NSObject, MFMailComposeViewControllerDelegate {
    public static let shared = EmailPresenter()
    private override init() { }

    func present() {
        if !MFMailComposeViewController.canSendMail() {
            presentAlert(title: "Email Client", message: "Your device must have the native iOS email app installed for this feature.", primaryAction: .OK)
            return
        }
        let picker = MFMailComposeViewController()
        picker.setToRecipients([AppConfig.emailSupport])
        picker.mailComposeDelegate = self
        rootController?.present(picker, animated: true, completion: nil)
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        rootController?.dismiss(animated: true, completion: nil)
    }
}

// MARK: - Settings Section Background view
struct SectionBackgroundView: ViewModifier {
    @State var bottomPadding: Double = 0.0
    func body(content: Content) -> some View {
        content.padding([.top, .bottom], 5).background(
            RoundedRectangle(cornerRadius: 12).foregroundColor(.white)
                .shadow(color: .black.opacity(0.05), radius: 2)
        ).padding(.bottom, bottomPadding)
    }
}
