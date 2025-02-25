import SwiftUI
import RevenueCat

struct RevenueCatPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var manager: DataManager
    
    @State private var selectedPackage: Package?
    @State private var packages: [Package] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let features = AppConfig.premiumFeaturesList
    
    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    HeaderView
                    FeaturesView
                    PackagesView
                    RestoreButton
                    PrivacyTermsView
                }.padding(.bottom, 20)
            }
            
            CloseButton
            
            if isLoading {
                LoadingView
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await loadOffering()
        }
    }
    
    private var HeaderView: some View {
        VStack(spacing: 0) {
            Image(systemName: "crown.fill")
                .font(.system(size: 100))
                .padding(20)
                .foregroundColor(.headerTextColor)
            
            Text("Premium Version")
                .font(.largeTitle)
                .bold()
            
            Text("Unlock All Features")
                .font(.headline)
        }
        .foregroundColor(.headerTextColor)
    }
    
    private var FeaturesView: some View {
        VStack {
            ForEach(features, id: \.self) { feature in
                HStack {
                    Image(systemName: "checkmark.circle")
                        .resizable()
                        .frame(width: 25, height: 25)
                    Text(feature)
                        .font(.system(size: 22))
                    Spacer()
                }
            }
            .padding(.horizontal, 30)
            Spacer(minLength: 45)
        }
        .foregroundColor(.primary)
        .padding(.top, 40)
    }
    
    private var PackagesView: some View {
        VStack(spacing: 10) {
            ForEach(packages, id: \.identifier) { package in
                PackageButton(package: package)
            }
        }
        .padding(.horizontal, 30)
    }
    
    private func PackageButton(package: Package) -> some View {
        Button {
            selectedPackage = package
            Task {
                await purchasePackage(package)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 28.5)
                    .foregroundColor(.primary)
                    .frame(height: 57)
                
                VStack(spacing: 4) {
                    Text(package.storeProduct.subscriptionPeriod?.periodTitle ?? "")
                        .foregroundColor(.white)
                        .bold()
                    Text(package.storeProduct.localizedPriceString)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.subheadline)
                }
            }
        }
    }
    
    private var RestoreButton: some View {
        Button {
            Task {
                await restorePurchases()
            }
        } label: {
            Text("Restore Purchases")
                .foregroundColor(.primary)
                .opacity(0.7)
        }
        .padding(.top, 20)
    }
    
    private var PrivacyTermsView: some View {
        HStack(spacing: 20) {
            Button {
                UIApplication.shared.open(AppConfig.privacyURL)
            } label: {
                Text("Privacy Policy")
            }
            
            Button {
                UIApplication.shared.open(AppConfig.termsAndConditionsURL)
            } label: {
                Text("Terms & Conditions")
            }
        }
        .font(.system(size: 10))
        .foregroundColor(.primary)
        .padding()
    }
    
    private var CloseButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Color.backgroundColor
                        Image(systemName: "xmark")
                    }
                }
                .frame(width: 20, height: 20)
                .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding()
    }
    
    private var LoadingView: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
        }
    }
    
    private func loadOffering() async {
        do {
            guard let offering = try await RevenueCatConfig.shared.getOffering() else {
                errorMessage = "No offerings available"
                return
            }
            packages = offering.availablePackages
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func purchasePackage(_ package: Package) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let customerInfo = try await RevenueCatConfig.shared.purchase(package: package)
            if customerInfo.entitlements[RevenueCatConfig.entitlementIdentifier]?.isActive == true {
                manager.isPremiumUser = true
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let customerInfo = try await RevenueCatConfig.shared.restorePurchases()
            if customerInfo.entitlements[RevenueCatConfig.entitlementIdentifier]?.isActive == true {
                manager.isPremiumUser = true
                dismiss()
            } else {
                errorMessage = "No purchases to restore"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension SubscriptionPeriod {
    var periodTitle: String {
        switch self.unit {
        case .week:
            return "Weekly"
        case .month:
            return "Monthly"
        case .year:
            return "Yearly"
        case .day:
            return "Daily"
        @unknown default:
            return "Unknown"
        }
    }
} 