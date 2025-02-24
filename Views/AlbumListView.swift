//
//  AlbumListView.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import SwiftUI
import Photos

struct AlbumListView: View {
    @EnvironmentObject var manager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var albums: PHFetchResult<PHAssetCollection>?
    @State private var showCreateAlbum = false
    @State private var newAlbumTitle = ""
    @State private var isCreatingAlbum = false
    let assetId: String
    
    var body: some View {
        NavigationView {
            List {
                // Create new album button
                Button(action: { showCreateAlbum = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                        Text("Create New Album")
                            .foregroundColor(.primary)
                    }
                }
                
                // Existing albums
                if let albums = albums {
                    ForEach(0..<albums.count, id: \.self) { index in
                        let album = albums.object(at: index)
                        Button(action: {
                            addToAlbum(album)
                        }) {
                            HStack {
                                Image(systemName: "photo.stack")
                                    .foregroundColor(.gray)
                                Text(album.localizedTitle ?? "Untitled Album")
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Create New Album", isPresented: $showCreateAlbum) {
                TextField("Album Title", text: $newAlbumTitle)
                Button("Cancel", role: .cancel) {
                    newAlbumTitle = ""
                }
                Button("Create") {
                    createNewAlbum()
                }
            }
            .onAppear {
                albums = manager.fetchUserAlbums()
            }
        }
    }
    
    private func createNewAlbum() {
        guard !newAlbumTitle.isEmpty else { return }
        isCreatingAlbum = true
        
        manager.createAlbum(withTitle: newAlbumTitle) { success, error in
            DispatchQueue.main.async {
                isCreatingAlbum = false
                if success {
                    albums = manager.fetchUserAlbums()
                    if let newAlbum = albums?.lastObject {
                        addToAlbum(newAlbum)
                    }
                } else if let error = error {
                    presentAlert(title: "Error", message: error.localizedDescription, primaryAction: .OK)
                }
                newAlbumTitle = ""
            }
        }
    }
    
    private func addToAlbum(_ album: PHAssetCollection) {
        manager.addAssetToAlbum(assetId: assetId, album: album) { success, error in
            DispatchQueue.main.async {
                if success {
                    dismiss()
                } else if let error = error {
                    presentAlert(title: "Error", message: error.localizedDescription, primaryAction: .OK)
                }
            }
        }
    }
}

#Preview {
    AlbumListView(assetId: "")
        .environmentObject(DataManager())
} 