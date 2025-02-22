//
//  DataManager.swift
//  SwipeClean
//
//  Created by Apps4World on 1/3/25.
//

import Photos
import SwiftUI
import PhotosUI
import CoreData
import Foundation

/// Main data manager for the app
class DataManager: NSObject, ObservableObject {
    
    /// Dynamic properties that the UI will react to
    @Published var fullScreenMode: FullScreenMode?
    @Published var selectedTab: CustomTabBarItem = .discover
    @Published var galleryAssets: [AssetModel] = [AssetModel]()
    @Published var didGrantPermissions: Bool = false
    @Published var didProcessAssets: Bool = false
    @Published var onThisDateHeaderImage: UIImage?
    @Published var assetsSwipeStack: [AssetModel] = [AssetModel]()
    @Published var removeStackAssets: [AssetModel] = [AssetModel]()
    @Published var keepStackAssets: [AssetModel] = [AssetModel]()
    @Published var swipeStackLoadMore: Bool = false
    @Published var swipeStackTitle: String = AppConfig.swipeStackOnThisDateTitle
   
    /// Dynamic properties that the UI will react to AND store values in UserDefaults
    @AppStorage("freePhotosStackCount") var freePhotosStackCount: Int = 0
    @AppStorage("didShowOnboardingFlow") var didShowOnboardingFlow: Bool = false
    @AppStorage(AppConfig.premiumVersion) var isPremiumUser: Bool = false {
        didSet { Interstitial.shared.isPremiumUser = isPremiumUser }
    }
    
    /// Core Data container with the database model
    private let container: NSPersistentContainer = NSPersistentContainer(name: "Database")
    
    /// Photo Library properties
    private let imageManager: PHImageManager = PHImageManager()
    private var fetchResult: PHFetchResult<PHAsset>!
    private var assetsByMonth: [CalendarMonth: [PHAsset]] = [CalendarMonth: [PHAsset]]()
    
    /// Default initializer
    override init() {
        super.init()
        prepareCoreData()
        configurePlaceholderAssets()
        checkAuthorizationStatus()
    }
    
    /// Sorted months based on current date
    var sortedMonths: [CalendarMonth] {
        CalendarMonth.allCases
    }
}

// MARK: - Onboarding implementation
extension DataManager {
    func getStarted() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
            DispatchQueue.main.async {
                self.didShowOnboardingFlow = true
                self.removeStackAssets.removeAll()
                self.keepStackAssets.removeAll()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.checkAuthorizationStatus()
                    Interstitial.shared.loadInterstitial()
                }
            }
        }
    }
    
    /// Check if the user granted permissions to their photo library
    private func checkAuthorizationStatus() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            DispatchQueue.main.async {
                PHPhotoLibrary.shared().register(self)
                self.didGrantPermissions = true
                self.fetchLibraryAssets()
            }
        default:
            DispatchQueue.main.async {
                self.didGrantPermissions = false
            }
        }
    }
}

// MARK: - Discover Tab implementation
extension DataManager {
    private func configurePlaceholderAssets() {
        CalendarMonth.allCases.forEach { month in
            var placeholders: [AssetModel] = [AssetModel]()
            for index in 0..<3 {
                placeholders.append(.init(id: "placeholder-\(index)-\(month.rawValue)", month: month))
            }
            galleryAssets.append(contentsOf: placeholders)
        }
    }
    
    /// Get up to 3 assets for a given month
    /// - Parameter month: month to get the assets for Discover tab
    /// - Returns: returns up to 3 assets (or placeholders)
    func assetsPreview(for month: CalendarMonth) -> [AssetModel] {
        Array(galleryAssets.filter { $0.month == month }.prefix(3))
    }
    
    /// Get the total number of assets for a given month
    /// - Parameter month: month to get the assets count for
    /// - Returns: returns the number of assets for a month
    func assetsCount(for month: CalendarMonth) -> Int? {
        guard let assets = assetsByMonth[month] else { return nil }
        
        // Get deleted asset identifiers from Core Data
        let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
        let deletedAssetIdentifiers = (try? container.viewContext.fetch(fetchRequest).compactMap { $0.assetIdentifier }) ?? []
        
        // Filter out deleted assets before counting
        let nonDeletedAssets = assets.filter { !deletedAssetIdentifiers.contains($0.localIdentifier) }
        return nonDeletedAssets.count
    }
    
    /// Check if the user has photos for this date in current year or previous years
    var hasPhotosOnThisDate: Bool {
        onThisDateHeaderImage != nil
    }
}

// MARK: - Swipe Tab implementation
extension DataManager {
    /// Mark asset as `keep`
    /// - Parameter model: asset model
    func keepAsset(_ model: AssetModel) {
        model.swipeStackImage = nil
        keepStackAssets.appendIfNeeded(model)
        assetsSwipeStack.removeAll(where: { $0.id == model.id })
        guard !model.id.starts(with: "onboarding") else { return }
        freePhotosStackCount += 1
        appendStackAssetsIfNeeded()
    }
    
    /// Mark asset as `delete`
    /// - Parameter model: asset model
    func deleteAsset(_ model: AssetModel) {
        guard !model.id.starts(with: "onboarding") else {
            removeStackAssets.appendIfNeeded(model)
            assetsSwipeStack.removeAll(where: { $0.id == model.id })
            return
        }
        
        let assetIdentifier: String = model.id
        let imageSize: CGSize = AppConfig.sectionItemThumbnailSize
        if let asset = assetsByMonth.flatMap({ $0.value }).first(where: { $0.localIdentifier == assetIdentifier }) {
            requestImage(for: asset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                model.thumbnail = image
                model.swipeStackImage = nil
                self.removeStackAssets.appendIfNeeded(model)
                self.assetsSwipeStack.removeAll(where: { $0.id == model.id })
                self.freePhotosStackCount += 1
                self.appendStackAssetsIfNeeded()
                self.saveDeletedAsset(assetIdentifier: assetIdentifier)
                
                // Refresh gallery assets to update counts and previews
                DispatchQueue.main.async {
                    self.refreshGalleryAssets()
                }
            }
        } else {
            presentAlert(title: "Oops!", message: "Something went wrong with this image", primaryAction: .Cancel)
        }
    }
    
    /// Append more assets to the stack
    private func appendStackAssetsIfNeeded() {
        // Only try to load more if we have 50 or fewer assets
        guard assetsSwipeStack.count <= 50 else { return }
        
        let onThisDate: Bool = swipeStackTitle == AppConfig.swipeStackOnThisDateTitle
        let month: CalendarMonth? = CalendarMonth(rawValue: swipeStackTitle.lowercased())
        
        // Check if we have more assets available before showing loading state
        var hasMoreAssets = false
        if onThisDate {
            hasMoreAssets = assetsByMonth[Date().month]?
                .filter { asset in
                    let isNotInStacks = !assetsSwipeStack.contains { $0.id == asset.localIdentifier } &&
                                      !keepStackAssets.contains { $0.id == asset.localIdentifier }
                    let isOnThisDate = asset.creationDate?.string(format: "MM/dd") == Date().string(format: "MM/dd")
                    return isNotInStacks && isOnThisDate
                }
                .count ?? 0 > 0
        } else if let month = month {
            hasMoreAssets = assetsByMonth[month]?
                .filter { asset in
                    !assetsSwipeStack.contains { $0.id == asset.localIdentifier } &&
                    !keepStackAssets.contains { $0.id == asset.localIdentifier }
                }
                .count ?? 0 > 0
        }
        
        if hasMoreAssets {
            swipeStackLoadMore = true
            Interstitial.shared.showInterstitialAds()
            DispatchQueue.global(qos: .userInitiated).async {
                self.updateSwipeStack(with: month, onThisDate: onThisDate, switchTabs: false)
                DispatchQueue.main.async { self.swipeStackLoadMore = false }
            }
        }
    }
}

// MARK: - Photo Bin implementation
extension DataManager {
    /// Move a `delete` item back `assetsSwipeStack`
    /// - Parameter model: asset model
    func restoreAsset(_ model: AssetModel) {
        removeStackAssets.removeAll(where: { $0.id == model.id })
        removeDeletedAsset(assetIdentifier: model.id)
        
        // Refresh gallery assets to update counts and previews
        DispatchQueue.main.async {
            self.refreshGalleryAssets()
        }
    }
    
    /// Save asset as deleted in Core Data
    private func saveDeletedAsset(assetIdentifier: String) {
        let deletedAsset = DeletedAsset(context: container.viewContext)
        deletedAsset.assetIdentifier = assetIdentifier
        deletedAsset.dateMarkedForDeletion = Date()
        try? container.viewContext.save()
    }
    
    /// Remove asset from deleted in Core Data
    private func removeDeletedAsset(assetIdentifier: String) {
        let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "assetIdentifier = %@", assetIdentifier)
        if let deletedAsset = try? container.viewContext.fetch(fetchRequest).first {
            container.viewContext.delete(deletedAsset)
            try? container.viewContext.save()
        }
    }
    
    /// Load all deleted assets from Core Data
    private func loadDeletedAssets() {
        let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
        if let deletedAssets = try? container.viewContext.fetch(fetchRequest) {
            DispatchQueue.main.async {
                self.removeStackAssets.removeAll() // Clear existing assets before loading
                
                for deletedAsset in deletedAssets {
                    if let assetIdentifier = deletedAsset.assetIdentifier {
                        let assetModel = AssetModel(id: assetIdentifier, month: Date().month)
                        if let asset = self.assetsByMonth.flatMap({ $0.value }).first(where: { $0.localIdentifier == assetIdentifier }) {
                            let imageSize: CGSize = AppConfig.sectionItemThumbnailSize
                            self.requestImage(for: asset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                                assetModel.thumbnail = image
                                DispatchQueue.main.async {
                                    self.removeStackAssets.appendIfNeeded(assetModel)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Refresh gallery assets to update counts and previews
    private func refreshGalleryAssets() {
        galleryAssets.removeAll()
        
        for month in CalendarMonth.allCases {
            guard let assets = assetsByMonth[month], !assets.isEmpty else { continue }
            // Filter out deleted assets from gallery preview
            let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
            let deletedAssetIdentifiers = (try? container.viewContext.fetch(fetchRequest).compactMap { $0.assetIdentifier }) ?? []
            let nonDeletedAssets = assets.filter { !deletedAssetIdentifiers.contains($0.localIdentifier) }
            let assetsToAdd = nonDeletedAssets.prefix(3)
            
            for asset in assetsToAdd {
                let assetModel = AssetModel(id: asset.localIdentifier, month: month, isVideo: asset.mediaType == .video)
                let assetIdentifier = asset.localIdentifier + "_thumbnail"
                let imageSize = AppConfig.sectionItemThumbnailSize
                requestImage(for: asset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                    assetModel.thumbnail = image
                }
                galleryAssets.append(assetModel)
            }
        }
        
        // Also refresh the "On This Date" header image
        let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
        let deletedAssetIdentifiers = (try? container.viewContext.fetch(fetchRequest).compactMap { $0.assetIdentifier }) ?? []
        
        if let thisDateAsset = assetsByMonth[Date().month]?
            .sorted(by: { $0.creationDate ?? Date() > $1.creationDate ?? Date() })
            .filter({ !deletedAssetIdentifiers.contains($0.localIdentifier) })
            .first(where: { $0.creationDate?.string(format: "MM/dd") == Date().string(format: "MM/dd") }) {
            let assetIdentifier = thisDateAsset.localIdentifier + "_onThisDate"
            let imageSize = AppConfig.onThisDateItemSize
            requestImage(for: thisDateAsset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                DispatchQueue.main.async {
                    self.onThisDateHeaderImage = image
                }
            }
        } else {
            DispatchQueue.main.async {
                self.onThisDateHeaderImage = nil
            }
        }
    }
}

// MARK: - Photo Library implementation
extension DataManager {
    private func fetchLibraryAssets() {
        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchResult = PHAsset.fetchAssets(with: allPhotosOptions)
        processFetchResult()
    }
    
    /// Process fetch result assets
    private func processFetchResult() {
        fetchResult.enumerateObjects { asset, _, _ in
            guard let creationDate = asset.creationDate else { return }
            self.assetsByMonth[creationDate.month, default: []].append(asset)
        }
        
        /// Load previously deleted assets
        loadDeletedAssets()
        
        /// Update the SwipeClean tab with `On This Date` photos by default
        updateSwipeStack(onThisDate: true, switchTabs: false)
        
        /// Add up to 3 assets for each month to `galleryAssets`
        galleryAssets.removeAll()
        for month in CalendarMonth.allCases {
            guard let assets = assetsByMonth[month], !assets.isEmpty else { continue }
            // Filter out deleted assets from gallery preview
            let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
            let deletedAssetIdentifiers = (try? container.viewContext.fetch(fetchRequest).compactMap { $0.assetIdentifier }) ?? []
            let nonDeletedAssets = assets.filter { !deletedAssetIdentifiers.contains($0.localIdentifier) }
            let assetsToAdd = nonDeletedAssets.prefix(3)
            
            for asset in assetsToAdd {
                let assetModel = AssetModel(id: asset.localIdentifier, month: month, isVideo: asset.mediaType == .video)
                let assetIdentifier = asset.localIdentifier + "_thumbnail"
                let imageSize = AppConfig.sectionItemThumbnailSize
                requestImage(for: asset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                    assetModel.thumbnail = image
                }
                galleryAssets.append(assetModel)
            }
        }
        
        /// Fetch the image for `On This Date` header
        let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
        let deletedAssetIdentifiers = (try? container.viewContext.fetch(fetchRequest).compactMap { $0.assetIdentifier }) ?? []
        
        if let thisDateAsset = assetsByMonth[Date().month]?
            .sorted(by: { $0.creationDate ?? Date() > $1.creationDate ?? Date() })
            .filter({ !deletedAssetIdentifiers.contains($0.localIdentifier) }) // Filter out deleted assets
            .first(where: { $0.creationDate?.string(format: "MM/dd") == Date().string(format: "MM/dd") }) {
            let assetIdentifier = thisDateAsset.localIdentifier + "_onThisDate"
            let imageSize = AppConfig.onThisDateItemSize
            requestImage(for: thisDateAsset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                DispatchQueue.main.async {
                    self.onThisDateHeaderImage = image
                }
            }
        }
        
        /// Show the `Discover` tab
        DispatchQueue.main.async {
            self.didProcessAssets = true
        }
    }
    
    /// Update the `assetsSwipeStack` with selected category
    func updateSwipeStack(with calendarMonth: CalendarMonth? = nil, onThisDate: Bool = false, switchTabs: Bool = true) {
        func appendSwipeStackAsset(_ asset: PHAsset) {
            let assetIdentifier = asset.localIdentifier
            // Check if the asset is marked for deletion in Core Data
            let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "assetIdentifier = %@", assetIdentifier)
            if (try? container.viewContext.fetch(fetchRequest))?.isEmpty ?? true {
                let imageSize = AppConfig.swipeStackItemSize
                requestImage(for: asset, assetIdentifier: assetIdentifier, size: imageSize) { image in
                    func appendAsset() {
                        if let assetImage = image {
                            let assetModel = AssetModel(id: asset.localIdentifier, month: Date().month, isVideo: asset.mediaType == .video)
                            assetModel.swipeStackImage = assetImage
                            assetModel.creationDate = asset.creationDate?.string(format: "MMMM dd, yyyy")
                            self.assetsSwipeStack.appendIfNeeded(assetModel)
                        }
                    }
                    if switchTabs { appendAsset() } else {
                        DispatchQueue.main.async { appendAsset() }
                    }
                }
            }
        }
        
        func shouldAppendAsset(_ asset: PHAsset) -> Bool {
            let assetIdentifier = asset.localIdentifier
            let isNotInSwipeStack = !assetsSwipeStack.contains { $0.id == assetIdentifier }
            let isNotInKeepStack = !keepStackAssets.contains { $0.id == assetIdentifier }
            let isNotDeleted = (try? container.viewContext.fetch(DeletedAsset.fetchRequest()).filter { $0.assetIdentifier == assetIdentifier }).map { $0.isEmpty } ?? true
            return isNotInSwipeStack && isNotInKeepStack && isNotDeleted
        }
        
        var assets: [PHAsset] = [PHAsset]()
        
        if onThisDate {
            assets = assetsByMonth[Date().month]?
                .sorted(by: { $0.creationDate ?? Date() > $1.creationDate ?? Date() })
                .filter({ $0.creationDate?.string(format: "MM/dd") == Date().string(format: "MM/dd") }) ?? []
        } else {
            guard let month = calendarMonth else { return }
            assets = assetsByMonth[month] ?? []
        }
        
        if switchTabs {
            assetsSwipeStack.removeAll()
            keepStackAssets.removeAll()
            selectedTab = .swipeClean
        }
        
        DispatchQueue.main.async {
            let thisDateTitle: String = AppConfig.swipeStackOnThisDateTitle
            self.swipeStackTitle = onThisDate ? thisDateTitle : calendarMonth?.rawValue.capitalized ?? ""
        }
        
        // Get all available assets that can be added
        let availableAssets = assets.filter(shouldAppendAsset)
        
        // If we have no assets in the stack and no available assets, return early
        if assetsSwipeStack.isEmpty && availableAssets.isEmpty {
            return
        }
        
        // Load more assets, but ensure we don't exceed array bounds
        let currentCount = assetsSwipeStack.count
        let batchSize = 100 // Increased batch size
        let assetsToLoad = min(batchSize - currentCount, availableAssets.count)
        
        if assetsToLoad > 0 {
            // Load assets in smaller chunks to prevent memory spikes
            let chunk = 20
            for i in stride(from: 0, to: assetsToLoad, by: chunk) {
                let end = min(i + chunk, assetsToLoad)
                let assetChunk = availableAssets[i..<end]
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i/chunk) * 0.5) {
                    assetChunk.forEach { appendSwipeStackAsset($0) }
                }
            }
        }
    }
    
    /// Empty the photo bin and remove all deleted assets from Core Data
    func emptyPhotoBin() {
        let itemsCount: Int = removeStackAssets.count
        presentAlert(title: "Delete Photos", message: "Are you sure you want to delete these \(itemsCount) photos?", primaryAction: .Cancel, secondaryAction: .init(title: "Delete", style: .destructive, handler: { _ in
            let allAssets = self.assetsByMonth.flatMap { $0.value }
            let removeStackAssetIdentifiers = self.removeStackAssets.compactMap { $0.id }
            let assetsToRemove = allAssets.filter { removeStackAssetIdentifiers.contains($0.localIdentifier) }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToRemove as NSArray)
            } completionHandler: { success, error in
                if success {
                    DispatchQueue.main.async {
                        // Remove all deleted assets from Core Data
                        let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
                        if let deletedAssets = try? self.container.viewContext.fetch(fetchRequest) {
                            for deletedAsset in deletedAssets {
                                self.container.viewContext.delete(deletedAsset)
                            }
                            try? self.container.viewContext.save()
                        }
                        self.removeStackAssets.removeAll()
                    }
                } else if let errorMessage = error?.localizedDescription {
                    presentAlert(title: "Oops!", message: errorMessage, primaryAction: .OK)
                }
            }
        }))
    }
}

// MARK: - Handle Photo Library changes
extension DataManager: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let changes = changeInstance.changeDetails(for: fetchResult) else { return }
        DispatchQueue.main.async {
            self.assetsByMonth.removeAll()
            self.assetsSwipeStack.removeAll()
            self.keepStackAssets.removeAll()
            self.fetchResult = changes.fetchResultAfterChanges
            self.processFetchResult()
        }
    }
}

// MARK: - Core Data implementation
extension DataManager {
    private func prepareCoreData() {
        container.loadPersistentStores { _, _ in
            self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
    }
    
    /// Saves the asset image to Core Data
    /// - Parameters:
    ///   - image: asset image to be saved
    ///   - assetIdentifier: asset identifier
    private func saveAsset(image: UIImage?, assetIdentifier: String) {
        guard let assetData = image?.jpegData(compressionQuality: 1) else { return }
        let assetEntity: AssetEntity = AssetEntity(context: container.viewContext)
        assetEntity.assetIdentifier = assetIdentifier
        assetEntity.imageData = assetData
        try? container.viewContext.save()
    }
    
    /// Fetch cached asset image from Core Data
    /// - Parameter assetIdentifier: asset identifier
    /// - Returns: returns the image if available
    private func fetchCachedImage(for assetIdentifier: String) -> UIImage? {
        let fetchRequest: NSFetchRequest<AssetEntity> = AssetEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "assetIdentifier = %@", assetIdentifier)
        if let imageData = try? container.viewContext.fetch(fetchRequest).first?.imageData {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    /// Request image from photo library for a given asset identifier
    /// - Parameters:
    ///   - asset: asset from the library
    ///   - assetIdentifier: asset identifier used to save the image to Core Data
    ///   - size: image size to be requested
    ///   - completion: returns the image if available
    private func requestImage(for asset: PHAsset, assetIdentifier: String,
                              size: CGSize, completion: @escaping (_ image: UIImage?) -> Void) {
        if let cachedImage = fetchCachedImage(for: assetIdentifier) {
            completion(cachedImage)
        } else {
            imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: .opportunistic) { image, _ in
                self.saveAsset(image: image, assetIdentifier: assetIdentifier)
                completion(image)
            }
        }
    }
    
    /// Load video asset and return URL
    /// - Parameters:
    ///   - assetIdentifier: The identifier of the video asset
    ///   - completion: Completion handler with optional URL
    func loadVideoAsset(for assetIdentifier: String, completion: @escaping (URL?) -> Void) {
        guard let asset = assetsByMonth.flatMap({ $0.value }).first(where: { $0.localIdentifier == assetIdentifier }),
              asset.mediaType == .video else {
            completion(nil)
            return
        }
        
        let options = PHVideoRequestOptions()
        options.version = .original
        options.deliveryMode = .automatic
        
        imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            if let urlAsset = avAsset as? AVURLAsset {
                completion(urlAsset.url)
            } else {
                completion(nil)
            }
        }
    }
}
