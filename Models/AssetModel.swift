//
//  AssetModel.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import UIKit
import Foundation

/// A model that represents a photo gallery asset (photo, video, live photo)
class AssetModel: Identifiable, ObservableObject {
    let id: String
    let month: CalendarMonth
    @Published var thumbnail: UIImage?
    @Published var swipeStackImage: UIImage?
    @Published var creationDate: String?
    var isVideo: Bool = false
    @Published var fileSize: String?
    var fileSizeBytes: Int64 = 0
    
    init(id: String, month: CalendarMonth, isVideo: Bool = false) {
        self.id = id
        self.month = month
        self.isVideo = isVideo
        self.thumbnail = UIImage(named: id)
        self.swipeStackImage = UIImage(named: id)
    }
}

/// Append asset if needed
extension Array where Element == AssetModel {
    mutating func appendIfNeeded(_ model: AssetModel) {
        if !contains(where: { $0.id == model.id }) {
            append(model)
        }
    }
}
