//
//  PixittApp.swift
//  Pixitt
//
//  Created by Apps4World on 1/3/25.
//

import Photos
import SwiftUI
import Combine

@main
struct PixittApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var manager: DataManager = DataManager()
    
    // MARK: - Main rendering function
    var body: some Scene {
        WindowGroup {
            if manager.didShowOnboardingFlow {
                DashboardContentView().environmentObject(manager)
            } else {
                OnboardingContentView().environmentObject(manager)
            }
        }
    }
}

/// Present an alert from anywhere in the app
func presentAlert(title: String, message: String, primaryAction: UIAlertAction, secondaryAction: UIAlertAction? = nil, tertiaryAction: UIAlertAction? = nil) {
    DispatchQueue.main.async {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(primaryAction)
        if let secondary = secondaryAction { alert.addAction(secondary) }
        if let tertiary = tertiaryAction { alert.addAction(tertiary) }
        rootController?.present(alert, animated: true, completion: nil)
    }
}

extension UIAlertAction {
    static var Cancel: UIAlertAction {
        UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
    }
    
    static var OK: UIAlertAction {
        UIAlertAction(title: "OK", style: .cancel, handler: nil)
    }
}

var windowScene: UIWindowScene? {
    let allScenes = UIApplication.shared.connectedScenes
    return allScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
}

var rootController: UIViewController? {
    var root = UIApplication.shared.connectedScenes
        .filter({ $0.activationState == .foregroundActive })
        .first(where: { $0 is UIWindowScene }).flatMap({ $0 as? UIWindowScene })?.windows
        .first(where: { $0.isKeyWindow })?.rootViewController
    while root?.presentedViewController != nil {
        root = root?.presentedViewController
    }
    return root
}

/// Handle certain date operations
extension Date {
    func string(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: self)
    }
    
    var month: CalendarMonth {
        let monthIndex: Int = Calendar.current.component(.month, from: self) - 1
        return CalendarMonth(rawValue: CalendarMonth.allCases[monthIndex].rawValue)!
    }
}

/// Create a shape with specific rounded corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

/// Custom fetch options
extension PHImageRequestOptions {
    static var opportunistic: PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.isSynchronous = true
        return options
    }
}

/// Integer formatter
extension Int {
    var string: String {
        if self >= 1000 && self < 1000000 {
            return String(format: "%.1fk", Double(self) / 1_000.0)
        }
        return String(self)
    }
}
