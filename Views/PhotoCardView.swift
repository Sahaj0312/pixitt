//
//  PhotoCardView.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import SwiftUI
import AVKit

/// A swipe card showing an asset
struct PhotoCardView: View {
    
    @EnvironmentObject var manager: DataManager
    @State private var cardOffset: CGFloat = 0
    @State var fromOnboardingFlow: Bool = false
    @State private var player: AVPlayer?
    @State private var isVideoLoaded: Bool = false
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
            .rotationEffect(.init(degrees: cardOffset == 0 ? 0 : (cardOffset > 0 ? 12 : -12)))
            .gesture(
                DragGesture().onChanged { value in
                    guard isSwipingEnabled else { return }
                    withAnimation(.default) {
                        cardOffset = value.translation.width
                    }
                }.onEnded { value in
                    guard isSwipingEnabled else { return }
                    updateCardEndPosition()
                }
            )
            .disabled(!hasFreeSwipes)
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
        VStack {
            Spacer()
            if let date = asset.creationDate {
                Text(date).padding(8).padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundStyle(.white).opacity(0.8)
                    )
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.primaryTextColor).padding(.top, 38)
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
    
    /// Update card position after the user lifts the finger off the screen
    private func updateCardEndPosition() {
        withAnimation(.easeIn){
            /// When user swipes right
            if cardOffset > 150 {
                cardOffset = 500
                manager.keepAsset(asset)

            /// When user swipes left
            } else if cardOffset < -150 {
                cardOffset = -500
                manager.deleteAsset(asset)
            } else {
                cardOffset = 0
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
        return manager.freePhotosStackCount < AppConfig.freePhotosStackCount
    }
    
    private func loadVideo() {
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
