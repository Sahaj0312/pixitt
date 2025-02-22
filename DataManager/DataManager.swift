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
    @Published var selectedAssets: Set<String> = []
   
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
    private var assetsByYearMonth: [Int: [CalendarMonth: [PHAsset]]] = [:]
    
    /// Track last ad shown timestamp
    private var lastAdShownTime: Date = Date.distantPast
    
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
            // Get asset resource to determine file size
            let resources = PHAssetResource.assetResources(for: asset)
            let fileSize = resources.first?.value(forKey: "fileSize") as? Int64 ?? 0
            model.fileSizeBytes = fileSize
            model.fileSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            
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
        // Only try to load more if we have 15 or fewer assets
        guard assetsSwipeStack.count <= 15 else { return }
        
        let onThisDate: Bool = swipeStackTitle == AppConfig.swipeStackOnThisDateTitle
        let month: CalendarMonth? = CalendarMonth(rawValue: swipeStackTitle.lowercased())
        
        // Optimize the hasMoreAssets check by doing Core Data fetch once
        let deletedAssets = (try? container.viewContext.fetch(DeletedAsset.fetchRequest())) ?? []
        let deletedIdentifiers = Set(deletedAssets.compactMap { $0.assetIdentifier })
        
        var hasMoreAssets = false
        if onThisDate {
            hasMoreAssets = assetsByMonth[Date().month]?
                .filter { asset in
                    let isNotInStacks = !assetsSwipeStack.contains { $0.id == asset.localIdentifier } &&
                                      !keepStackAssets.contains { $0.id == asset.localIdentifier }
                    let isOnThisDate = asset.creationDate?.string(format: "MM/dd") == Date().string(format: "MM/dd")
                    let isNotDeleted = !deletedIdentifiers.contains(asset.localIdentifier)
                    return isNotInStacks && isOnThisDate && isNotDeleted
                }
                .count ?? 0 > 0
        } else if let month = month {
            hasMoreAssets = assetsByMonth[month]?
                .filter { asset in
                    let isNotInStacks = !assetsSwipeStack.contains { $0.id == asset.localIdentifier } &&
                                      !keepStackAssets.contains { $0.id == asset.localIdentifier }
                    let isNotDeleted = !deletedIdentifiers.contains(asset.localIdentifier)
                    return isNotInStacks && isNotDeleted
                }
                .count ?? 0 > 0
        }
        
        if hasMoreAssets {
            swipeStackLoadMore = true
            
            // Show ad only if enough time has passed (30 seconds between ads)
            let timeSinceLastAd = Date().timeIntervalSince(lastAdShownTime)
            if timeSinceLastAd >= 45 && !isPremiumUser {
                lastAdShownTime = Date()
                Interstitial.shared.showInterstitialAds()
            }
            
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
        assetsByMonth.removeAll()
        assetsByYearMonth.removeAll()
        
        fetchResult.enumerateObjects { asset, _, _ in
            guard let creationDate = asset.creationDate else { return }
            let year = Calendar.current.component(.year, from: creationDate)
            let month = creationDate.month
            
            // Store in assetsByMonth for backward compatibility
            self.assetsByMonth[month, default: []].append(asset)
            
            // Store in assetsByYearMonth
            if self.assetsByYearMonth[year] == nil {
                self.assetsByYearMonth[year] = [:]
            }
            self.assetsByYearMonth[year]?[month, default: []].append(asset)
        }
        
        /// Load previously deleted assets
        loadDeletedAssets()
        
        /// Update the SwipeClean tab with `On This Date` photos by default
        updateSwipeStack(onThisDate: true, switchTabs: false)
        
        /// Add up to 3 assets for each month to `galleryAssets`
        refreshGalleryAssets()
        
        /// Show the `Discover` tab
        DispatchQueue.main.async {
            self.didProcessAssets = true
        }
    }
    
    /// Get available years in descending order
    var availableYears: [Int] {
        Array(assetsByYearMonth.keys).sorted(by: >)
    }
    
    /// Get available months for a given year
    func availableMonths(for year: Int) -> [CalendarMonth] {
        guard let yearData = assetsByYearMonth[year] else { return [] }
        return Array(yearData.keys).sorted { month1, month2 in
            let monthIndex1 = CalendarMonth.allCases.firstIndex(of: month1) ?? 0
            let monthIndex2 = CalendarMonth.allCases.firstIndex(of: month2) ?? 0
            return monthIndex1 < monthIndex2
        }
    }
    
    /// Get assets preview for a specific year and month
    func assetsPreview(for month: CalendarMonth, year: Int) -> [AssetModel] {
        guard let yearData = assetsByYearMonth[year],
              let monthAssets = yearData[month] else { return [] }
        
        // Filter out deleted assets
        let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
        let deletedAssetIdentifiers = (try? container.viewContext.fetch(fetchRequest).compactMap { $0.assetIdentifier }) ?? []
        let nonDeletedAssets = monthAssets.filter { !deletedAssetIdentifiers.contains($0.localIdentifier) }
        
        return nonDeletedAssets.prefix(3).map { asset in
            let assetModel = AssetModel(id: asset.localIdentifier, month: month, isVideo: asset.mediaType == .video)
            
            // Load image synchronously for preview
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.isSynchronous = true
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            
            imageManager.requestImage(
                for: asset,
                targetSize: AppConfig.sectionItemThumbnailSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                assetModel.thumbnail = image
            }
            
            return assetModel
        }
    }
    
    /// Get the total number of assets for a given year and month
    func assetsCount(for month: CalendarMonth, year: Int) -> Int? {
        guard let yearData = assetsByYearMonth[year],
              let assets = yearData[month] else { return nil }
        
        // Get deleted asset identifiers from Core Data
        let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
        let deletedAssetIdentifiers = (try? container.viewContext.fetch(fetchRequest).compactMap { $0.assetIdentifier }) ?? []
        
        // Filter out deleted assets before counting
        let nonDeletedAssets = assets.filter { !deletedAssetIdentifiers.contains($0.localIdentifier) }
        return nonDeletedAssets.count
    }
    
    /// Update the `assetsSwipeStack` with selected category
    func updateSwipeStack(with calendarMonth: CalendarMonth? = nil, year: Int? = nil, onThisDate: Bool = false, switchTabs: Bool = true) {
        func appendSwipeStackAsset(_ asset: PHAsset) {
            let assetIdentifier = asset.localIdentifier
            // Check if the asset is marked for deletion in Core Data
            let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "assetIdentifier = %@", assetIdentifier)
            if (try? container.viewContext.fetch(fetchRequest))?.isEmpty ?? true {
                // Request full resolution image for swipe stack
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                options.isSynchronous = false
                options.resizeMode = .none
                options.version = .current
                
                // Get asset resource to determine file size
                let resources = PHAssetResource.assetResources(for: asset)
                let fileSize = resources.first?.value(forKey: "fileSize") as? Int64 ?? 0
                let formattedSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                
                // First load a quick preview
                imageManager.requestImage(
                    for: asset,
                    targetSize: AppConfig.swipeStackItemSize,
                    contentMode: .aspectFill,
                    options: options
                ) { previewImage, _ in
                    if let previewImage = previewImage {
                        // Use the correct month based on the context
                        let assetMonth: CalendarMonth
                        if onThisDate {
                            assetMonth = asset.creationDate?.month ?? Date().month
                        } else {
                            assetMonth = calendarMonth ?? (asset.creationDate?.month ?? Date().month)
                        }
                        
                        let assetModel = AssetModel(id: asset.localIdentifier, month: assetMonth, isVideo: asset.mediaType == .video)
                        assetModel.swipeStackImage = previewImage
                        assetModel.creationDate = asset.creationDate?.string(format: "MMMM dd, yyyy")
                        assetModel.fileSize = formattedSize
                        
                        DispatchQueue.main.async {
                            // Only append if it matches the current filter
                            if onThisDate {
                                if asset.creationDate?.string(format: "MM/dd") == Date().string(format: "MM/dd") {
                                    self.assetsSwipeStack.appendIfNeeded(assetModel)
                                }
                            } else if let month = calendarMonth, let targetYear = year {
                                let assetYear = Calendar.current.component(.year, from: asset.creationDate ?? Date())
                                if assetMonth == month && assetYear == targetYear {
                                    self.assetsSwipeStack.appendIfNeeded(assetModel)
                                }
                            }
                            
                            // Then load the full quality version
                            self.imageManager.requestImageDataAndOrientation(for: asset, options: options) { imageData, _, _, _ in
                                if let data = imageData, let fullImage = UIImage(data: data) {
                                    DispatchQueue.main.async {
                                        assetModel.swipeStackImage = fullImage
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        var assets: [PHAsset] = [PHAsset]()
        
        if onThisDate {
            assets = assetsByMonth[Date().month]?
                .sorted(by: { $0.creationDate ?? Date() > $1.creationDate ?? Date() })
                .filter({ $0.creationDate?.string(format: "MM/dd") == Date().string(format: "MM/dd") }) ?? []
        } else if let month = calendarMonth, let targetYear = year {
            assets = assetsByYearMonth[targetYear]?[month] ?? []
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
        let batchSize = 50 // Reduced batch size for better performance
        let assetsToLoad = min(batchSize - currentCount, availableAssets.count)
        
        if assetsToLoad > 0 {
            // Load assets in smaller chunks to prevent memory spikes
            let chunk = 10 // Smaller chunks for smoother loading
            for i in stride(from: 0, to: assetsToLoad, by: chunk) {
                let end = min(i + chunk, assetsToLoad)
                let assetChunk = availableAssets[i..<end]
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i/chunk) * 0.2) { // Reduced delay
                    assetChunk.forEach { appendSwipeStackAsset($0) }
                }
            }
        }
    }
    
    /// Empty the photo bin and remove all deleted assets from Core Data
    func emptyPhotoBin(assets: [AssetModel]? = nil) {
        let itemsCount: Int = assets?.count ?? removeStackAssets.count
        let assetsToDelete = assets ?? removeStackAssets
        
        let allAssets = assetsByMonth.flatMap { $0.value }
        let removeStackAssetIdentifiers = assetsToDelete.compactMap { $0.id }
        let assetsToRemove = allAssets.filter { removeStackAssetIdentifiers.contains($0.localIdentifier) }
        
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assetsToRemove as NSArray)
        } completionHandler: { success, error in
            if success {
                DispatchQueue.main.async {
                    // Remove deleted assets from Core Data
                    let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
                    if let deletedAssets = try? self.container.viewContext.fetch(fetchRequest) {
                        for deletedAsset in deletedAssets {
                            if let identifier = deletedAsset.assetIdentifier,
                               removeStackAssetIdentifiers.contains(identifier) {
                                self.container.viewContext.delete(deletedAsset)
                            }
                        }
                        try? self.container.viewContext.save()
                    }
                    self.removeStackAssets.removeAll { removeStackAssetIdentifiers.contains($0.id) }
                }
            } else if let errorMessage = error?.localizedDescription {
                presentAlert(title: "Oops!", message: errorMessage, primaryAction: .OK)
            }
        }
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
        // Only cache swipe stack images, not thumbnails
        let shouldCache = !assetIdentifier.contains("_thumbnail") && !assetIdentifier.contains("_onThisDate")
        
        if shouldCache, let cachedImage = fetchCachedImage(for: assetIdentifier) {
            completion(cachedImage)
            return
        }
        
        let options = PHImageRequestOptions()
        
        if shouldCache {
            // For main swipe stack images, request maximum quality
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .none
            options.version = .current
            
            // Request the maximum possible resolution
            let targetSize = PHImageManagerMaximumSize
            
            imageManager.requestImageDataAndOrientation(for: asset, options: options) { imageData, _, _, _ in
                if let data = imageData, let image = UIImage(data: data) {
                    self.saveAsset(image: image, assetIdentifier: assetIdentifier)
                    completion(image)
                } else {
                    // Fallback to regular image request if data request fails
                    self.imageManager.requestImage(
                        for: asset,
                        targetSize: targetSize,
                        contentMode: .aspectFill,
                        options: options
                    ) { image, info in
                        if let finalImage = image {
                            self.saveAsset(image: finalImage, assetIdentifier: assetIdentifier)
                            completion(finalImage)
                        }
                    }
                }
            }
        } else {
            // For thumbnails, use fast loading
            options.deliveryMode = .fastFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            
            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                completion(image)
            }
        }
    }
    
    /// Check if an asset should be appended to the swipe stack
    private func shouldAppendAsset(_ asset: PHAsset) -> Bool {
        // Don't add if it's already in the swipe stack
        guard !assetsSwipeStack.contains(where: { $0.id == asset.localIdentifier }) else {
            return false
        }
        
        // Don't add if it's in the keep stack
        guard !keepStackAssets.contains(where: { $0.id == asset.localIdentifier }) else {
            return false
        }
        
        // Check if the asset is marked for deletion in Core Data
        let fetchRequest: NSFetchRequest<DeletedAsset> = DeletedAsset.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "assetIdentifier = %@", asset.localIdentifier)
        if let deletedAssets = try? container.viewContext.fetch(fetchRequest), !deletedAssets.isEmpty {
            return false
        }
        
        return true
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
