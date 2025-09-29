import SwiftUI
import Foundation

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

class AppearanceManager: ObservableObject {
    @Published var currentMode: AppearanceMode {
        didSet {
            saveAppearanceMode()
            updateAppearance()
        }
    }

    @Published var effectiveColorScheme: ColorScheme = .light

    private let userDefaults = UserDefaults.standard
    private let appearanceModeKey = "AppearanceMode"

    init() {
        // Load saved appearance mode
        if let savedMode = userDefaults.string(forKey: appearanceModeKey),
           let mode = AppearanceMode(rawValue: savedMode) {
            self.currentMode = mode
        } else {
            self.currentMode = .system
        }

        updateAppearance()
        setupSystemAppearanceObserver()
    }

    private func saveAppearanceMode() {
        userDefaults.set(currentMode.rawValue, forKey: appearanceModeKey)
    }

    private func updateAppearance() {
        DispatchQueue.main.async {
            switch self.currentMode {
            case .system:
                self.effectiveColorScheme = self.getSystemColorScheme()
            case .light:
                self.effectiveColorScheme = .light
            case .dark:
                self.effectiveColorScheme = .dark
            }
        }
    }

    private func getSystemColorScheme() -> ColorScheme {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.traitCollection.userInterfaceStyle == .dark ? .dark : .light
        }
        return .light
    }

    private func setupSystemAppearanceObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.currentMode == .system {
                self?.updateAppearance()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Appearance-Aware Gradient Backgrounds

extension AppearanceManager {
    var backgroundGradient: [Color] {
        switch effectiveColorScheme {
        case .light:
            return [
                Color(red: 0.1, green: 0.3, blue: 0.8),
                Color(red: 0.2, green: 0.5, blue: 0.9),
                Color(red: 0.4, green: 0.7, blue: 1.0),
                Color(red: 0.6, green: 0.8, blue: 1.0)
            ]
        case .dark:
            return [
                Color(red: 0.05, green: 0.1, blue: 0.3),
                Color(red: 0.1, green: 0.2, blue: 0.4),
                Color(red: 0.15, green: 0.25, blue: 0.5),
                Color(red: 0.2, green: 0.3, blue: 0.6)
            ]
        @unknown default:
            return [
                Color(red: 0.1, green: 0.3, blue: 0.8),
                Color(red: 0.2, green: 0.5, blue: 0.9),
                Color(red: 0.4, green: 0.7, blue: 1.0),
                Color(red: 0.6, green: 0.8, blue: 1.0)
            ]
        }
    }

    var glassOpacity: Double {
        switch effectiveColorScheme {
        case .light:
            return 0.1
        case .dark:
            return 0.15
        @unknown default:
            return 0.1
        }
    }

    var strokeOpacity: Double {
        switch effectiveColorScheme {
        case .light:
            return 0.3
        case .dark:
            return 0.5
        @unknown default:
            return 0.3
        }
    }

    var cardGlassColor: Color {
        switch effectiveColorScheme {
        case .light:
            return .white
        case .dark:
            return .white
        @unknown default:
            return .white
        }
    }

    var shadowOpacity: Double {
        switch effectiveColorScheme {
        case .light:
            return 0.1
        case .dark:
            return 0.3
        @unknown default:
            return 0.1
        }
    }

    var blueAccentOpacity: Double {
        switch effectiveColorScheme {
        case .light:
            return 0.05
        case .dark:
            return 0.08
        @unknown default:
            return 0.05
        }
    }

    // True glassmorphism material properties
    var ultraThinGlass: Double {
        switch effectiveColorScheme {
        case .light:
            return 0.05
        case .dark:
            return 0.08
        @unknown default:
            return 0.05
        }
    }

    var glassBlur: CGFloat {
        switch effectiveColorScheme {
        case .light:
            return 20
        case .dark:
            return 30
        @unknown default:
            return 20
        }
    }
}