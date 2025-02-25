//
//  SwipeTabView.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import SwiftUI

/// The tab to swipe left/right on photos stack
struct SwipeTabView: View {
    
    @EnvironmentObject var manager: DataManager
    
    // MARK: - Main rendering function
    var body: some View {
        VStack {
            VStack {
                ZStack {
                    EmptyStackOverlay
                    ForEach(manager.assetsSwipeStack.reversed()) { asset in
                        PhotoCardView(asset: asset)
                    }
                }.padding([.top, .horizontal], 10)
                
            }.padding(.bottom, 5).background(
                RoundedRectangle(cornerRadius: 28).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.05), radius: 8)
            ).background(CardsStackBackground).padding(.horizontal)
            
            Text(manager.swipeStackTitle).padding(8).padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(.white))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.primaryTextColor).padding(.top, 38)
            
            Spacer()
        }
    }
    
    /// Keep/Delete button with style
    private func ActionButton(image: String, color: Color,
                        action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            ZStack {
                Circle().foregroundStyle(color)
                Image(systemName: image).foregroundStyle(.white)
                    .font(.system(size: 28, weight: .black, design: .rounded))
            }
        }.frame(width: 70, height: 70)
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
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 40)).padding(5)
                Text("Done Swiping").font(.title2).fontWeight(.bold)
                Text("You've reviewed all photos. Check your delete list in the '\(CustomTabBarItem.photoBin.rawValue)' tab.")
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
    
    /// Verify it the user has any free swipes
    private var hasFreeSwipes: Bool {
        guard !manager.isPremiumUser else { return true }
        manager.checkAndResetDailySwipeCount()
        return manager.freePhotosStackCount < AppConfig.freePhotosStackCount
    }
    
    /// Check if swipe limit has been reached and show paywall if needed
    private func checkSwipeLimit() {
        guard !manager.isPremiumUser else { return }
        manager.checkAndResetDailySwipeCount()
        if manager.freePhotosStackCount >= AppConfig.freePhotosStackCount {
            DispatchQueue.main.async {
                manager.fullScreenMode = .premium
            }
        }
    }
}

// MARK: - Preview UI
#Preview {
    let manager = DataManager()
    manager.didGrantPermissions = true
    return ZStack {
        Color.backgroundColor.ignoresSafeArea()
        SwipeTabView().environmentObject(manager)
    }
}
