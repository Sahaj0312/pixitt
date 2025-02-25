//
//  HomeTabView.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import SwiftUI

/// The main home tab to show photo gallery sections
struct HomeTabView: View {
    
    @EnvironmentObject var manager: DataManager
    private let gridSpacing: Double = 10.0
    
    // MARK: - Main rendering function
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 35) {
                // Top sections row
                HStack(spacing: 15) {
                    OnThisDateSection
                    VideosSection
                }.padding(.top, 10)
                
                ForEach(manager.availableYears, id: \.self) { year in
                    YearSection(year: year)
                }
            }.padding(.horizontal)
            Spacer(minLength: 20)
        }
    }
    
    // MARK: - On This Date section
    private var OnThisDateSection: some View {
        let tileHeight: Double = UIScreen.main.bounds.width/2 - 25.0
        return ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            
            if let image = manager.onThisDateHeaderImage {
                Button { manager.updateSwipeStack(onThisDate: true) } label: {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: tileHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            } else {
                NoPhotosOverlay
            }
            
            // Title overlay at the bottom
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Date().string(format: "MMMM d"))
                            .font(.system(size: 15, weight: .medium))
                        Text("On This Date")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    Spacer()
                }
                .padding(15)
                .background(
                    RoundedCorner(radius: 25, corners: [.bottomLeft, .bottomRight])
                        .fill(Color.black.opacity(0.3))
                )
            }
        }
        .frame(height: tileHeight)
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .opacity(manager.didGrantPermissions ? 1 : 0)
        .overlay(PermissionsView().opacity(manager.didGrantPermissions ? 0 : 1))
    }
    
    // MARK: - Videos section
    private var VideosSection: some View {
        let tileHeight: Double = UIScreen.main.bounds.width/2 - 25.0
        return ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            
            if let firstVideo = manager.videosPreview.first, let thumbnail = firstVideo.thumbnail {
                Button { 
                    if manager.isPremiumUser {
                        manager.updateSwipeStack(videosOnly: true)
                    } else {
                        manager.fullScreenMode = .premium
                    }
                } label: {
                    ZStack {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: tileHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Play button overlay
                        Circle()
                            .fill(.white.opacity(0.9))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 25, weight: .bold))
                                    .foregroundStyle(.black)
                                    .offset(x: 2)
                            )
                            
                        // Premium lock overlay for non-premium users
                        if !manager.isPremiumUser {
                            ZStack {
                                Color.black.opacity(0.5)
                                    .frame(height: tileHeight)
                                VStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Premium")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                        }
                    }
                }
            } else {
                NoVideosOverlay
            }
            
            // Title overlay at the bottom
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let count = manager.videosCount {
                            Text("\(count) Videos")
                                .font(.system(size: 15, weight: .medium))
                        }
                        Text("Videos")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    Spacer()
                    // Add lock icon for non-premium users
                    if !manager.isPremiumUser {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.trailing, 5)
                    }
                }
                .padding(15)
                .background(
                    RoundedCorner(radius: 25, corners: [.bottomLeft, .bottomRight])
                        .fill(Color.black.opacity(0.3))
                )
            }
        }
        .frame(height: tileHeight)
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .opacity(manager.didGrantPermissions ? 1 : 0)
        .overlay(PermissionsView().opacity(manager.didGrantPermissions ? 0 : 1))
    }
    
    /// No photos on this date
    private var NoPhotosOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 35))
                .foregroundStyle(.gray)
            Text("No Photos Today")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.gray)
            Text("Check back later for memories")
                .font(.system(size: 14))
                .foregroundStyle(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    /// No videos overlay
    private var NoVideosOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.system(size: 35))
                .foregroundStyle(.gray)
            Text("No Videos")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.gray)
            Text("No videos in your library")
                .font(.system(size: 14))
                .foregroundStyle(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Year section with horizontal month scrolling
    private func YearSection(year: Int) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(String(year))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primaryTextColor)
                .padding(.leading, 5)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(manager.availableMonths(for: year), id: \.self) { month in
                        MonthPreview(month: month, year: year)
                    }
                }.padding(.horizontal, 5)
            }
        }
    }
    
    // MARK: - Month preview card
    private func MonthPreview(month: CalendarMonth, year: Int) -> some View {
        Button { manager.updateSwipeStack(with: month, year: year) } label: {
            VStack(spacing: 8) {
                let previewSize: CGFloat = (UIScreen.main.bounds.width - 65.0)/3.5
                
                // Single preview image with count overlay
                ZStack {
                    let assets = manager.assetsPreview(for: month, year: year)
                    if !assets.isEmpty, let firstAsset = assets.first {
                        PreviewImage(asset: firstAsset, size: previewSize)
                        
                        // Count overlay
                        if let count = manager.assetsCount(for: month, year: year), count > 1 {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text("+\(count - 1)")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 14, weight: .semibold))
                                        .padding(6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .foregroundStyle(Color.primaryTextColor.opacity(0.8))
                                        )
                                        .padding(8)
                                }
                            }
                        }
                    } else {
                        // Empty state
                        RoundedRectangle(cornerRadius: 8)
                            .frame(width: previewSize, height: previewSize)
                            .foregroundStyle(Color.secondaryTextColor.opacity(0.2))
                    }
                }
                .frame(width: previewSize, height: previewSize)
                
                // Month name
                Text(month.rawValue.capitalized)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.primaryTextColor)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 2)
            )
            .padding(.vertical, 4)
        }
    }
    
    private func PreviewImage(asset: AssetModel, size: CGFloat) -> some View {
        ZStack {
            if let thumbnail = asset.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Loading state
                RoundedRectangle(cornerRadius: 8)
                    .frame(width: size, height: size)
                    .foregroundStyle(Color.secondaryTextColor.opacity(0.2))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }
        }
        .frame(width: size, height: size)
    }
    
    /// Grid item asset image
    private func GridItemImage(for asset: AssetModel) -> some View {
        ZStack {
            if let thumbnail = asset.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
    }
    
    /// Custom shape for rounded corners
    private struct RoundedCorner: Shape {
        var radius: CGFloat = .infinity
        var corners: UIRectCorner = .allCorners

        func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                  cornerRadii: CGSize(width: radius, height: radius))
            return Path(path.cgPath)
        }
    }
}

// MARK: - Preview UI
#Preview {
    let manager = DataManager()
    manager.didGrantPermissions = true
    manager.didProcessAssets = true
    return HomeTabView().environmentObject(manager)
}
