//
//  PhotoBinTabView.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import SwiftUI

/// Shows a grid of assets to be deleted
struct PhotoBinTabView: View {
    
    @EnvironmentObject var manager: DataManager
    private let gridSpacing: Double = 10.0
    
    // MARK: - Main rendering function
    var body: some View {
        VStack {
            if manager.removeStackAssets.count == 0 {
                EmptyDeleteAssetsList
            } else {
                AssetsGridListView
            }
        }
    }
    
    /// Empty delete assets list
    private var EmptyDeleteAssetsList: some View {
        ZStack {
            VStack {
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(0..<9, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12)
                            .frame(height: tileHeight)
                            .foregroundStyle(Color.secondaryTextColor).opacity(0.2)
                    }
                }.padding(.horizontal).padding(.bottom).overlay(
                    VStack {
                        LinearGradient(colors: [.backgroundColor.opacity(0), .backgroundColor], startPoint: .top, endPoint: .bottom)
                        Spacer()
                    }
                ).opacity(0.8)
                Spacer()
            }
            
            VStack {
                Spacer()
                Image(systemName: "trash.slash")
                    .font(.system(size: 40)).padding(5)
                Text("Bin is Empty").font(.title2).fontWeight(.bold)
                Text("No photos marked for deletion. Swipe through your photos to add them here.")
                    .font(.body).multilineTextAlignment(.center).opacity(0.6)
                    .padding(.horizontal).fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
    }
    
    /// Assets grid list view
    private var AssetsGridListView: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(manager.removeStackAssets) { asset in
                    AssetGridItem(for: asset)
                }
            }.padding(.horizontal)
            Spacer(minLength: 20)
        }
    }
    
    /// Asset grid item
    private func AssetGridItem(for model: AssetModel) -> some View {
        return RoundedRectangle(cornerRadius: 12).frame(height: tileHeight)
            .foregroundStyle(Color.secondaryTextColor).opacity(0.2)
            .overlay(AssetImage(for: model)).clipped()
            .overlay(ItemSelectionOverlay(for: model))
            .clipShape(RoundedRectangle(cornerRadius: 15))
    }
    
    /// Item selection overlay
    private func ItemSelectionOverlay(for model: AssetModel) -> some View {
        VStack {
            HStack {
                Spacer()
                Button { manager.restoreAsset(model) } label: {
                    ZStack {
                        Circle().foregroundStyle(.white)
                        Image(systemName: "checkmark.circle.fill")
                            .resizable().aspectRatio(contentMode: .fit).padding(2)
                    }.frame(width: 25, height: 25)
                }
            }.padding(8)
            Spacer()
        }
    }
    
    /// Asset image preview overlay
    private func AssetImage(for model: AssetModel) -> some View {
        ZStack {
            if let thumbnail = model.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable().aspectRatio(contentMode: .fill)
            }
        }
    }
    
    /// Grid columns configuration
    private var columns: [GridItem] {
        Array(repeating: GridItem(spacing: gridSpacing), count: 3)
    }
    
    /// Grid item tile height
    private var tileHeight: Double {
        (UIScreen.main.bounds.width - 56.0)/3.0
    }
}

// MARK: - Preview UI
#Preview {
    let manager = DataManager()
    //manager.removeStackAssets = manager.galleryAssets
    return ZStack {
        Color.backgroundColor.ignoresSafeArea()
        PhotoBinTabView().environmentObject(manager)
    }
}
