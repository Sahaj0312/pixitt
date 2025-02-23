import RevenueCat

class RevenueCatConfig {
    static let shared = RevenueCatConfig()
    
    // Static identifiers
    static let entitlementIdentifier = "PRO"
    static let weeklyIdentifier = "ProWeekly"
    static let monthlyIdentifier = "ProMonthly"
    static let offeringIdentifier = "default"
    
    private init() {
        Purchases.configure(withAPIKey: "appl_lMuGMEnkrmaDgeawlZJEGeQHdtR")
        Purchases.logLevel = .debug
    }
    
    func isPremium() async -> Bool {
        let customerInfo = try? await Purchases.shared.customerInfo()
        return customerInfo?.entitlements[RevenueCatConfig.entitlementIdentifier]?.isActive == true
    }
    
    func purchase(package: Package) async throws -> CustomerInfo {
        let purchaseResult = try await Purchases.shared.purchase(package: package)
        return purchaseResult.customerInfo
    }
    
    func restorePurchases() async throws -> CustomerInfo {
        try await Purchases.shared.restorePurchases()
    }
    
    func getOffering() async throws -> Offering? {
        let offerings = try await Purchases.shared.offerings()
        return offerings.current ?? offerings.offering(identifier: RevenueCatConfig.offeringIdentifier)
    }
} 