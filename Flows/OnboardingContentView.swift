//
//  OnboardingContentView.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import SwiftUI

/// The screen that shows up when the app launches the first time
struct OnboardingContentView: View {
    
    @EnvironmentObject var manager: DataManager
    
    // MARK: - Main rendering function
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            ZStack {
                EmptyStackOverlay
                ForEach(AppConfig.onboardingAssets) { asset in
                    PhotoCardView(fromOnboardingFlow: true, asset: asset)
                }
            }
            .padding(10).environmentObject(manager)
            .padding(.bottom, 5).background(
                RoundedRectangle(cornerRadius: 28).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.05), radius: 8)
            )
            .background(CardsStackBackground)
            .padding(.horizontal).padding(.bottom, 10)
            
            VStack {
                Text("Swipe")
                    .font(.system(size: 38, weight: .medium, design: .rounded))
                + Text("Clean")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("Swipe and Organize: Left to Delete,\nRight to Cherish")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center).opacity(0.7)
                Spacer()
                Button { manager.getStarted() } label: {
                    Text("Allow Access")
                        .bold().frame(maxWidth: .infinity).padding()
                        .background(isGetStartedEnabled ? Color.blue : Color.black)
                        .opacity(isGetStartedEnabled ? 1 : 0.4)
                        .foregroundColor(.white).cornerRadius(12)
                }.padding(.horizontal).disabled(!isGetStartedEnabled)
                Text("All photo handling is done on your device, without external access. We respect your privacy.")
                    .font(.system(size: 12, weight: .light))
                    .multilineTextAlignment(.center).opacity(0.7)
                    .padding(.horizontal, 40).padding(.top, 10)
            }.foregroundStyle(Color.primaryTextColor).padding(.top, 10)
        }
    }
    
    /// Empty stack of photo cards
    private var EmptyStackOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).frame(height: PhotoCardView.height)
                .foregroundStyle(LinearGradient(colors: [
                    .init(white: 0.94), .backgroundColor
                ], startPoint: .top, endPoint: .bottom)).background(
                    RoundedRectangle(cornerRadius: 25)
                        .foregroundStyle(LinearGradient(colors: [.red, .accentColor, .green], startPoint: .leading, endPoint: .trailing))
                        .offset(y: 20).padding().blur(radius: 20).opacity(0.3)
                )
            VStack {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 40)).padding(5)
                Text("Access Needed").font(.title2).fontWeight(.bold)
                Text("To start sorting your photos, SwipeClean needs access to your gallery.")
                    .font(.body).multilineTextAlignment(.center)
                    .padding(.horizontal).opacity(0.6)
            }
        }
    }
    
    /// Cards stack background
    private var CardsStackBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .padding(40).offset(y: 65).opacity(0.3)
            RoundedRectangle(cornerRadius: 28)
                .padding().offset(y: 30).opacity(0.6)
        }
        .foregroundStyle(Color.backgroundColor)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 5)
    }
    
    /// Verify if `Get Started` button must be enabled
    private var isGetStartedEnabled: Bool {
        let assets: [AssetModel] = manager.keepStackAssets + manager.removeStackAssets
        return AppConfig.onboardingAssets.filter { asset in
            assets.contains(where: { $0.id == asset.id })
        }.count == AppConfig.onboardingAssets.count
    }
}

// MARK: - Preview UI
#Preview {
    OnboardingContentView().environmentObject(DataManager())
}
