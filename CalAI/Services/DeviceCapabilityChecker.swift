import Foundation
import UIKit

/// Device capability checker for determining AI processing options
/// Automatically detects older devices and provides appropriate fallbacks
class DeviceCapabilityChecker {
    static let shared = DeviceCapabilityChecker()

    private init() {}

    // MARK: - Device Information

    /// Get the device model identifier (e.g., "iPhone15,2" for iPhone 14 Pro)
    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value))!)
        }
        return identifier
    }

    /// Get human-readable device name
    var deviceName: String {
        return UIDevice.current.model
    }

    /// Get iOS version
    var iOSVersion: String {
        return UIDevice.current.systemVersion
    }

    /// Get major iOS version number
    var iOSMajorVersion: Int {
        let version = UIDevice.current.systemVersion
        let majorVersion = version.components(separatedBy: ".").first ?? "0"
        return Int(majorVersion) ?? 0
    }

    // MARK: - Chip Detection

    /// Detect the chip type for Apple Intelligence compatibility
    var chipType: ChipType {
        let model = deviceModel.lowercased()

        // A18 Pro chips (iPhone 16 Pro series) - Best performance
        if model.contains("iphone17,") {
            return .a18Pro
        }

        // A18 chips (iPhone 16 series)
        if model.contains("iphone16,") {
            return .a18
        }

        // A17 Pro chips (iPhone 15 Pro series) - Apple Intelligence supported
        if model.contains("iphone16,") || model.contains("iphone15,2") || model.contains("iphone15,3") {
            return .a17Pro
        }

        // M-series chips (iPad/Mac) - Apple Intelligence supported
        if model.contains("ipad14,") || // M2 iPad Pro
           model.contains("ipad13,") || // M1 iPad Pro/Air
           model.contains("mac") {
            return .mSeries
        }

        // A17 chips (iPhone 15 base models) - No Apple Intelligence
        if model.contains("iphone15,4") || model.contains("iphone15,5") {
            return .a17
        }

        // A16 Bionic (iPhone 14 series) - No Apple Intelligence
        if model.contains("iphone14,") {
            return .a16Bionic
        }

        // A15 Bionic (iPhone 13 series) - No Apple Intelligence
        if model.contains("iphone13,") {
            return .a15Bionic
        }

        // A14 Bionic (iPhone 12 series) - No Apple Intelligence
        if model.contains("iphone12,") {
            return .a14Bionic
        }

        // Older chips - No Apple Intelligence
        if model.contains("iphone11,") {
            return .a13Bionic // iPhone 11 series
        }

        if model.contains("iphone10,") {
            return .a12Bionic // iPhone XS/XR series
        }

        if model.contains("iphone9,") {
            return .a11Bionic // iPhone X/8 series
        }

        // Default to older for unknown devices
        return .older
    }

    // MARK: - Capability Detection

    /// Check if device supports Apple Intelligence (iOS 26+ and A17 Pro/M-series or newer)
    var supportsAppleIntelligence: Bool {
        return iOSMajorVersion >= 26 && chipType.supportsAppleIntelligence
    }

    /// Check if FoundationModels framework is available
    var hasFoundationModels: Bool {
        #if canImport(FoundationModels)
        return true
        #else
        return false
        #endif
    }

    /// Check if device supports on-device AI processing
    var supportsOnDeviceAI: Bool {
        return supportsAppleIntelligence && hasFoundationModels
    }

    /// Get recommended AI provider based on device capabilities
    var recommendedAIProvider: AIProvider {
        if supportsOnDeviceAI {
            return .onDevice
        } else {
            // Default to Anthropic for better performance on older devices
            return .anthropic
        }
    }

    /// Get compatibility level for current device
    var compatibilityLevel: CompatibilityLevel {
        if supportsOnDeviceAI {
            return .fullSupport
        } else if iOSMajorVersion >= 17 && chipType.supportsFastProcessing {
            return .cloudAIOnly
        } else if iOSMajorVersion >= 15 {
            return .basicSupport
        } else {
            return .limitedSupport
        }
    }

    // MARK: - User Messaging

    /// Get user-friendly message about AI capabilities
    func getCapabilityMessage() -> String {
        let level = compatibilityLevel
        let chip = chipType.displayName
        let ios = iOSVersion

        switch level {
        case .fullSupport:
            return """
            ✅ Full AI Support Available
            Your \(deviceName) (\(chip), iOS \(ios)) supports both on-device AI (Apple Intelligence) and cloud AI for the best experience.

            • On-device AI: Private, fast, and free
            • Cloud AI: Advanced reasoning capabilities
            """

        case .cloudAIOnly:
            return """
            🌐 Cloud AI Available
            Your \(deviceName) (\(chip), iOS \(ios)) doesn't support Apple Intelligence, but works great with cloud AI services.

            • Anthropic Claude: Advanced reasoning and conversation
            • OpenAI GPT-4: Versatile and powerful responses
            • Requires internet connection and API key
            """

        case .basicSupport:
            return """
            📱 Basic Support
            Your \(deviceName) (\(chip), iOS \(ios)) supports core calendar features with cloud AI for enhanced functionality.

            • Basic calendar management works offline
            • AI features require internet and API key
            • Consider updating iOS for better performance
            """

        case .limitedSupport:
            return """
            ⚠️ Limited Support
            Your \(deviceName) (\(chip), iOS \(ios)) has limited AI capabilities.

            • Basic calendar functions work
            • AI features may be slower or unavailable
            • Consider updating iOS or device for full experience
            """
        }
    }

    /// Get short capability status for settings UI
    func getShortCapabilityStatus() -> String {
        switch compatibilityLevel {
        case .fullSupport:
            return "✅ Apple Intelligence + Cloud AI"
        case .cloudAIOnly:
            return "🌐 Cloud AI Only (\(chipType.displayName))"
        case .basicSupport:
            return "📱 Basic Support (iOS \(iOSMajorVersion))"
        case .limitedSupport:
            return "⚠️ Limited Support"
        }
    }

    // MARK: - Performance Recommendations

    /// Get performance optimization recommendations
    func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []

        if !supportsOnDeviceAI {
            recommendations.append("Use cloud AI (Anthropic/OpenAI) for best results")
        }

        if iOSMajorVersion < 17 {
            recommendations.append("Update to iOS 17+ for better performance")
        }

        if chipType.isOlderThanA14 {
            recommendations.append("Enable 'Fast Response Mode' for quicker interactions")
            recommendations.append("Use 'Pattern-Based' processing for better battery life")
        }

        if !hasFoundationModels && iOSMajorVersion >= 26 {
            recommendations.append("Enable Apple Intelligence in Settings for on-device AI")
        }

        return recommendations
    }
}

// MARK: - Supporting Types

enum ChipType {
    case a18Pro        // iPhone 16 Pro series - Latest
    case a18           // iPhone 16 series
    case a17Pro        // iPhone 15 Pro series - Apple Intelligence supported
    case mSeries       // iPad/Mac M-series - Apple Intelligence supported
    case a17           // iPhone 15 base models
    case a16Bionic     // iPhone 14 series
    case a15Bionic     // iPhone 13 series
    case a14Bionic     // iPhone 12 series
    case a13Bionic     // iPhone 11 series
    case a12Bionic     // iPhone XS/XR series
    case a11Bionic     // iPhone X/8 series
    case older         // iPhone 7 and older

    var supportsAppleIntelligence: Bool {
        switch self {
        case .a18Pro, .a18, .a17Pro, .mSeries:
            return true
        case .a17, .a16Bionic, .a15Bionic, .a14Bionic, .a13Bionic, .a12Bionic, .a11Bionic, .older:
            return false
        }
    }

    var supportsFastProcessing: Bool {
        switch self {
        case .a18Pro, .a18, .a17Pro, .mSeries, .a17, .a16Bionic, .a15Bionic, .a14Bionic:
            return true
        case .a13Bionic, .a12Bionic, .a11Bionic, .older:
            return false
        }
    }

    var isOlderThanA14: Bool {
        switch self {
        case .a18Pro, .a18, .a17Pro, .mSeries, .a17, .a16Bionic, .a15Bionic, .a14Bionic:
            return false
        case .a13Bionic, .a12Bionic, .a11Bionic, .older:
            return true
        }
    }

    var displayName: String {
        switch self {
        case .a18Pro: return "A18 Pro"
        case .a18: return "A18"
        case .a17Pro: return "A17 Pro"
        case .mSeries: return "M-series"
        case .a17: return "A17"
        case .a16Bionic: return "A16 Bionic"
        case .a15Bionic: return "A15 Bionic"
        case .a14Bionic: return "A14 Bionic"
        case .a13Bionic: return "A13 Bionic"
        case .a12Bionic: return "A12 Bionic"
        case .a11Bionic: return "A11 Bionic"
        case .older: return "A10 or older"
        }
    }
}

enum CompatibilityLevel {
    case fullSupport      // On-device AI + Cloud AI
    case cloudAIOnly      // Cloud AI only, good performance
    case basicSupport     // Cloud AI, limited performance
    case limitedSupport   // Very limited AI capabilities
}