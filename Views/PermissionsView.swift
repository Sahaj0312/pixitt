//
//  PermissionsView.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import SwiftUI

/// Asks the user to grant photo library permissions
struct PermissionsView: View {
    
    // MARK: - Main rendering function
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40)).padding(5)
            
            Text("Access Needed").font(.title2).fontWeight(.bold)
            Text("Please enable full photo library access in your device settings to use this app.")
                .font(.body).multilineTextAlignment(.center).opacity(0.6)
                .padding(.horizontal).fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            Button(action: openAppSettings) {
                Text("Open Settings")
                    .bold().frame(maxWidth: .infinity)
                    .padding().background(Color.blue)
                    .foregroundColor(.white).cornerRadius(12)
            }.padding()
        }
    }
    
    /// Open the app settings
    private func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsUrl) else { return }
        UIApplication.shared.open(settingsUrl)
    }
}

// MARK: - Preview UI
#Preview {
    PermissionsView()
}
