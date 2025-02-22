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
        ZStack {
            VStack {
                if manager.removeStackAssets.count == 0 {
                    EmptyDeleteAssetsList
                } else {
                    AssetsGridListView
                }
            }
            
            // Floating action buttons
            if !manager.selectedAssets.isEmpty {
                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        // Keep button
                        FloatingActionButton(
                            icon: "heart.fill",
                            color: .green,
                            action: {
                                for id in manager.selectedAssets {
                                    if let asset = manager.removeStackAssets.first(where: { $0.id == id }) {
                                        manager.restoreAsset(asset)
                                    }
                                }
                                manager.selectedAssets.removeAll()
                            }
                        )
                        
                        // Delete button
                        FloatingActionButton(
                            icon: "trash.fill",
                            color: .red,
                            action: {
                                // Show confirmation dialog
                                let count = manager.selectedAssets.count
                                presentAlert(
                                    title: "Delete Photos",
                                    message: "Are you sure you want to delete these \(count) photos?",
                                    primaryAction: .Cancel,
                                    secondaryAction: .init(title: "Delete", style: .destructive, handler: { _ in
                                        // Filter assets to delete
                                        let assetsToDelete = manager.removeStackAssets.filter { manager.selectedAssets.contains($0.id) }
                                        manager.emptyPhotoBin(assets: assetsToDelete)
                                        manager.selectedAssets.removeAll()
                                    })
                                )
                            }
                        )
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ToggleSelectAll"))) { _ in
            if manager.selectedAssets.count == manager.removeStackAssets.count {
                manager.selectedAssets.removeAll()
            } else {
                manager.selectedAssets = Set(manager.removeStackAssets.map { $0.id })
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
    
    /// Floating action button
    private func FloatingActionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 56, height: 56)
                    .shadow(radius: 4)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
        }
    }
    
    /// Assets grid list view
    private var AssetsGridListView: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(manager.removeStackAssets) { asset in
                    AssetGridItem(for: asset)
                        .onTapGesture {
                            if manager.selectedAssets.contains(asset.id) {
                                manager.selectedAssets.remove(asset.id)
                            } else {
                                manager.selectedAssets.insert(asset.id)
                            }
                        }
                }
            }.padding(.horizontal)
            Spacer(minLength: 20)
        }
    }
    
    /// Asset grid item
    private func AssetGridItem(for model: AssetModel) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .frame(height: tileHeight)
                .foregroundStyle(Color.secondaryTextColor)
                .opacity(0.2)
                .overlay(AssetImage(for: model))
                .clipped()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(manager.selectedAssets.contains(model.id) ? Color.blue : Color.clear, lineWidth: 3)
                )
            
            // Selection indicator
            if manager.selectedAssets.contains(model.id) {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .background(Circle().fill(Color.white))
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    /// Asset image preview overlay
    private func AssetImage(for model: AssetModel) -> some View {
        ZStack {
            if let thumbnail = model.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
