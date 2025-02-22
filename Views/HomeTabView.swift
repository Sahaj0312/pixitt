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
                OnThisDateSection
                ForEach(manager.availableYears, id: \.self) { year in
                    YearSection(year: year)
                }
            }.padding(.horizontal)
            Spacer(minLength: 20)
        }
    }
    
    // MARK: - On This Date section
    private var OnThisDateSection: some View {
        let tileHeight: Double = UIScreen.main.bounds.width - 100.0
        return RoundedRectangle(cornerRadius: 25).frame(height: tileHeight)
            .foregroundStyle(LinearGradient(colors: [
                .init(white: 0.94), .init(white: 0.97)
            ], startPoint: .top, endPoint: .bottom))
            .background(ShadowBackgroundView(height: tileHeight))
            .overlay(OnThisDateHeaderImage(height: tileHeight))
            .overlay(OnThisDateBottomOverlay)
            .overlay(PermissionsView().opacity(manager.didGrantPermissions ? 0 : 1))
    }
    
    /// On This Date header image
    private func OnThisDateHeaderImage(height: Double) -> some View {
        ZStack {
            if let image = manager.onThisDateHeaderImage {
                let width: Double = UIScreen.main.bounds.width - 32.0
                Button { manager.updateSwipeStack(onThisDate: true) } label: {
                    Image(uiImage: image)
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(height: height).frame(width: width)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                }
            }
        }.opacity(!manager.didGrantPermissions ? 0 : 1)
    }
    
    /// Custom shadow background
    private func ShadowBackgroundView(height: Double) -> some View {
        RoundedRectangle(cornerRadius: 25).offset(y: 20)
            .foregroundStyle(Color.accentColor).padding()
            .blur(radius: 10).opacity(0.5)
    }
    
    /// On This Date bottom overlay
    private var OnThisDateBottomOverlay: some View {
        VStack {
            Spacer()
            NoPhotosOverlay
            Spacer()
            HStack {
                VStack(alignment: .leading) {
                    Text(Date().string(format: "MMMM d"))
                        .font(.system(size: 15, weight: .medium))
                    Text("On This Date")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                }
                Spacer()
            }
            .foregroundStyle(Color.white)
            .padding(10).padding(.horizontal, 5).background(
                RoundedCorner(radius: 25, corners: [.bottomLeft, .bottomRight])
                    .foregroundStyle(Color.primaryTextColor).opacity(0.3)
            )
            .opacity(manager.didGrantPermissions ? 1 : 0)
        }.allowsHitTesting(false)
    }
    
    /// No photos on this date
    private var NoPhotosOverlay: some View {
        VStack {
            Image(systemName: "calendar")
                .font(.system(size: 40)).padding(5)
            Text("Empty Today").font(.title2).fontWeight(.bold)
            Text("Nothing from this date. Explore other memories or check back later.")
                .font(.body).multilineTextAlignment(.center)
                .padding(.horizontal).opacity(0.6)
        }.opacity(manager.didGrantPermissions && !manager.hasPhotosOnThisDate ? 1 : 0)
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
}

// MARK: - Preview UI
#Preview {
    let manager = DataManager()
    manager.didGrantPermissions = true
    manager.didProcessAssets = true
    return HomeTabView().environmentObject(manager)
}
