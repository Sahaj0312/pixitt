//
//  OverlayLoadingView.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import SwiftUI

/// Tab overlay loading view
struct OverlayLoadingView: View {
    
    @State var subtitle: String = "Processing your photo library"
    
    // MARK: - Main rendering function
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            VStack(spacing: 2) {
                Image(systemName: "hourglass").font(.largeTitle)
                Text("Please Wait...").font(.title2).fontWeight(.semibold)
                Text(subtitle).font(.body).fontWeight(.regular).opacity(0.5)
            }.padding(.bottom, 20)
        }
    }
}

// MARK: - Preview UI
#Preview {
    OverlayLoadingView()
}
