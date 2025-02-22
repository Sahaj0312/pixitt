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
                ForEach(0..<manager.sortedMonths.count, id: \.self) { index in
                    SectionPreview(for: manager.sortedMonths[index])
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
    
    // MARK: - Photos/Videos preview section for a given month
    private func SectionPreview(for month: CalendarMonth) -> some View {
        Button { manager.updateSwipeStack(with: month) } label: {
            VStack(spacing: 8) {
                HStack {
                    Text(month.rawValue.capitalized)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                    Spacer()
                }.foregroundStyle(Color.primaryTextColor)
                let tileHeight: Double = (UIScreen.main.bounds.width - 65.0)/3.0
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(0..<manager.assetsPreview(for: month).count, id: \.self) { index in
                        let asset: AssetModel = manager.assetsPreview(for: month)[index]
                        RoundedRectangle(cornerRadius: 15).frame(height: tileHeight)
                            .foregroundStyle(Color.secondaryTextColor).opacity(0.2)
                            .overlay(GridItemImage(for: asset)).clipped()
                            .overlay(TotalCountTag(for: month, index: index))
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                }
            }
        }
    }
    
    /// Grid item asset image
    private func GridItemImage(for asset: AssetModel) -> some View {
        ZStack {
            if let thumbnail = asset.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable().aspectRatio(contentMode: .fill)
            }
        }
    }
    
    /// Total assets count tag overlay
    private func TotalCountTag(for month: CalendarMonth, index: Int) -> some View {
        ZStack {
            if let count = manager.assetsCount(for: month), index == 2, count > 3 {
                RoundedRectangle(cornerRadius: 8).opacity(0.7)
                    .foregroundStyle(Color.primaryTextColor).padding(15)
                Text("+\(Int(count - 2).string)").foregroundStyle(.white)
                    .font(.system(size: 18, weight: .semibold))
            }
        }
    }
    
    /// Grid columns configuration
    private var columns: [GridItem] {
        Array(repeating: GridItem(spacing: gridSpacing), count: 3)
    }
}

// MARK: - Preview UI
#Preview {
    let manager = DataManager()
    manager.didGrantPermissions = true
    manager.didProcessAssets = true
    return HomeTabView().environmentObject(manager)
}
