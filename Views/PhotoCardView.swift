//
//  PhotoCardView.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import SwiftUI
import AVKit
import Photos

/// A swipe card showing an asset
struct PhotoCardView: View {
    
    @EnvironmentObject var manager: DataManager
    @State private var cardOffset: CGFloat = 0
    @State var fromOnboardingFlow: Bool = false
    @State private var player: AVPlayer?
    @State private var isVideoLoaded: Bool = false
    @State private var isSharePresented: Bool = false
    @State private var feedbackGenerator = UINotificationFeedbackGenerator()
    @State private var isAlbumListPresented: Bool = false
    static let height: Double = UIScreen.main.bounds.width * 1.4
    let asset: AssetModel
    
    /// Check if this card is the top card in the stack
    private var isTopCard: Bool {
        manager.assetsSwipeStack.first?.id == asset.id
    }
    
    // MARK: - Main rendering function
    var body: some View {
        RoundedRectangle(cornerRadius: 20).frame(height: PhotoCardView.height)
            .foregroundStyle(LinearGradient(colors: [
                .init(white: 0.94), .init(white: 0.97)
            ], startPoint: .top, endPoint: .bottom))
            .overlay(PermissionsView().opacity(manager.didGrantPermissions ? 0 : (fromOnboardingFlow ? 0 : 1)))
            .overlay(AssetPreviewOverlay).overlay(KeepDeleteOverlay)
            .overlay(AssetCreationDateTag).overlay(LoadingMoreOverlay)
            .offset(x: cardOffset)
            .rotationEffect(.init(degrees: rotationAngle))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard isSwipingEnabled else { return }
                        // Check swipe limit before allowing swipe
                        if !hasFreeSwipes {
                            checkSwipeLimit()
                            return
                        }
                        withAnimation(.interactiveSpring()) {
                            cardOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        guard isSwipingEnabled else { return }
                        // Check swipe limit before allowing swipe completion
                        if !hasFreeSwipes {
                            checkSwipeLimit()
                            return
                        }
                        let velocity = value.predictedEndLocation.x - value.location.x
                        updateCardEndPosition(with: velocity)
                    }
            )
            .disabled(false) // Never disable, we'll handle in gesture
            .onAppear {
                if asset.isVideo && isTopCard {
                    loadVideo()
                }
            }
            .onDisappear {
                player?.pause()
                player = nil
                isVideoLoaded = false
            }
            .onChange(of: isTopCard) { newValue in
                if newValue && asset.isVideo {
                    loadVideo()
                } else {
                    player?.pause()
                    player = nil
                    isVideoLoaded = false
                }
            }
            .sheet(isPresented: $isAlbumListPresented) {
                AlbumListView(assetId: asset.id)
            }
    }
    
    /// Asset preview overlay
    private var AssetPreviewOverlay: some View {
        ZStack {
            if asset.isVideo {
                if let player = player, isVideoLoaded && isTopCard {
                    let width: Double = UIScreen.main.bounds.width - 52.0
                    VideoPlayer(player: player)
                        .frame(height: PhotoCardView.height).frame(width: width)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .onAppear {
                            player.play()
                        }
                        .onDisappear {
                            player.pause()
                        }
                } else if let image = asset.swipeStackImage, !manager.swipeStackLoadMore {
                    let width: Double = UIScreen.main.bounds.width - 52.0
                    Image(uiImage: image)
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(height: PhotoCardView.height).frame(width: width)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            } else if let image = asset.swipeStackImage, !manager.swipeStackLoadMore {
                let width: Double = UIScreen.main.bounds.width - 52.0
                Image(uiImage: image)
                    .resizable().aspectRatio(contentMode: .fill)
                    .frame(height: PhotoCardView.height).frame(width: width)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }.opacity((manager.didGrantPermissions || fromOnboardingFlow) ? 1 : 0)
    }
    
    /// Asset creation date tag
    private var AssetCreationDateTag: some View {
        VStack(spacing: 10) {
            Spacer()
            // Add to Album button
            HStack {
                Button(action: {
                    if manager.isPremiumUser {
                        isAlbumListPresented = true
                    } else {
                        manager.fullScreenMode = .premium
                    }
                }) {
                    HStack {
                        Image(systemName: manager.isPremiumUser ? "folder.badge.plus" : "lock.fill")
                            .font(.system(size: 12))
                        Text("Add to Album")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                        if !manager.isPremiumUser {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(8)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundStyle(manager.isPremiumUser ? .white.opacity(0.8) : Color.headerTextColor.opacity(0.9))
                    )
                    .foregroundStyle(manager.isPremiumUser ? Color.primaryTextColor : .white)
                }
                Spacer()
            }
            
            // Share button
            HStack {
                Button(action: shareAsset) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12))
                        Text("Share")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .padding(8)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundStyle(.white).opacity(0.8)
                    )
                    .foregroundStyle(Color.primaryTextColor)
                }
                Spacer()
            }
            
            // Date and size
            HStack {
                if let date = asset.creationDate {
                    Text(date)
                        .padding(8)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .foregroundStyle(.white).opacity(0.8)
                        )
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.primaryTextColor)
                }
                Spacer()
                if let size = asset.fileSize {
                    Text(size)
                        .padding(8)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .foregroundStyle(.white).opacity(0.8)
                        )
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.primaryTextColor)
                }
            }
        }.padding()
    }
    
    /// Loading more assets to the stack
    private var LoadingMoreOverlay: some View {
        ZStack {
            if manager.swipeStackLoadMore {
                OverlayLoadingView(subtitle: "Loading more for '\(manager.swipeStackTitle)'")
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
    }
    
    /// Keep/Delete overlay
    private var KeepDeleteOverlay: some View {
        func overlay(text: String, color: Color) -> some View {
            Text(text).font(.system(size: 25, weight: .semibold, design: .rounded))
                .padding(8).padding(.horizontal, 10).background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).opacity(0.7)
                        RoundedRectangle(cornerRadius: 14).stroke(lineWidth: 4)
                    }.foregroundStyle(color)
                ).foregroundStyle(.white)
        }
        return VStack {
            HStack {
                overlay(text: "KEEP", color: .green)
                    .opacity(cardOffset > 30 ? 1 : 0)
                Spacer()
                overlay(text: "DELETE", color: .red)
                    .opacity(cardOffset < -30 ? 1 : 0)
            }.padding()
            Spacer()
        }
    }
    
    /// Calculate rotation angle based on offset
    private var rotationAngle: Double {
        // Make rotation proportional to offset but cap it
        let maxRotation = 8.0
        let rotationFactor = 0.1
        return min(max(cardOffset * rotationFactor, -maxRotation), maxRotation)
    }
    
    /// Update card position after the user lifts the finger off the screen
    private func updateCardEndPosition(with velocity: CGFloat) {
        let threshold: CGFloat = 100
        let velocityThreshold: CGFloat = 300
        
        // Prepare haptic feedback
        feedbackGenerator.prepare()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
            // Swipe right (Keep)
            if cardOffset > threshold || velocity > velocityThreshold {
                cardOffset = UIScreen.main.bounds.width
                feedbackGenerator.notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    manager.keepAsset(asset)
                }
            }
            // Swipe left (Delete)
            else if cardOffset < -threshold || velocity < -velocityThreshold {
                cardOffset = -UIScreen.main.bounds.width
                feedbackGenerator.notificationOccurred(.warning)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    manager.deleteAsset(asset)
                }
            }
            // Return to center
            else {
                cardOffset = 0
                let impactGenerator = UIImpactFeedbackGenerator(style: .light)
                impactGenerator.impactOccurred()
            }
        }
    }
    
    /// Verify if the card can be swiped
    private var isSwipingEnabled: Bool {
        fromOnboardingFlow || (manager.didGrantPermissions && manager.assetsSwipeStack.count > 0 && !manager.swipeStackLoadMore)
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
    
    /// Share the current asset
    private func shareAsset() {
        var items: [Any] = []
        
        if asset.isVideo {
            // For videos, we need to get the video URL
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .current
            
            manager.loadVideoAsset(for: asset.id) { url in
                if let url = url {
                    items.append(url)
                    DispatchQueue.main.async {
                        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first,
                           let rootVC = window.rootViewController {
                            rootVC.present(activityVC, animated: true)
                        }
                    }
                }
            }
        } else {
            // For images, we can use the swipeStackImage directly
            if let image = asset.swipeStackImage {
                items.append(image)
                let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            }
        }
    }
    
    private func loadVideo() {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current
        
        manager.loadVideoAsset(for: asset.id) { url in
            if let url = url {
                DispatchQueue.main.async {
                    self.player = AVPlayer(url: url)
                    self.player?.actionAtItemEnd = .none
                    
                    // Loop the video
                    NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem, queue: .main) { _ in
                        self.player?.seek(to: CMTime.zero)
                        self.player?.play()
                    }
                    
                    self.isVideoLoaded = true
                }
            }
        }
    }
}

// MARK: - Preview UI
#Preview {
    let manager = DataManager()
    manager.didGrantPermissions = true
    return PhotoCardView(fromOnboardingFlow: true, asset: .init(id: "", month: .may))
        .padding().environmentObject(manager)
}
