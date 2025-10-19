import Foundation
import SwiftUI

/// Manages custom colors for events
class EventColorManager: ObservableObject {
    static let shared = EventColorManager()

    private let defaults = UserDefaults.standard
    private let customColorsKey = "eventCustomColors"
    private let useCustomColorKey = "eventUseCustomColor"

    // Predefined color options for quick selection
    static let predefinedColors: [Color] = [
        Color(red: 255/255, green: 59/255, blue: 48/255),   // Red
        Color(red: 255/255, green: 149/255, blue: 0/255),   // Orange
        Color(red: 255/255, green: 204/255, blue: 0/255),   // Yellow
        Color(red: 52/255, green: 199/255, blue: 89/255),   // Green
        Color(red: 0/255, green: 199/255, blue: 190/255),   // Teal
        Color(red: 48/255, green: 176/255, blue: 199/255),  // Light Blue
        Color(red: 50/255, green: 173/255, blue: 230/255),  // Blue
        Color(red: 88/255, green: 86/255, blue: 214/255),   // Indigo
        Color(red: 175/255, green: 82/255, blue: 222/255),  // Purple
        Color(red: 255/255, green: 45/255, blue: 85/255),   // Pink
        Color(red: 142/255, green: 142/255, blue: 147/255), // Gray
        Color(red: 99/255, green: 99/255, blue: 102/255)    // Dark Gray
    ]

    private init() {}

    // MARK: - Custom Color Management

    /// Set a custom color for an event
    func setCustomColor(_ color: Color, for eventId: String) {
        objectWillChange.send()
        var colors = getCustomColors()
        colors[eventId] = color.toHex()
        saveCustomColors(colors)
    }

    /// Get custom color for an event
    func getCustomColor(for eventId: String) -> Color? {
        let colors = getCustomColors()
        guard let hexString = colors[eventId] else { return nil }
        return Color(hex: hexString)
    }

    /// Remove custom color for an event
    func removeCustomColor(for eventId: String) {
        objectWillChange.send()
        var colors = getCustomColors()
        colors.removeValue(forKey: eventId)
        saveCustomColors(colors)
    }

    /// Check if event has custom color
    func hasCustomColor(for eventId: String) -> Bool {
        let colors = getCustomColors()
        return colors[eventId] != nil
    }

    // MARK: - Use Custom Color Flag

    /// Set whether to use custom color for an event
    func setUseCustomColor(_ use: Bool, for eventId: String) {
        objectWillChange.send()
        var flags = getUseCustomColorFlags()
        flags[eventId] = use
        saveUseCustomColorFlags(flags)
    }

    /// Check if event should use custom color
    func shouldUseCustomColor(for eventId: String) -> Bool {
        let flags = getUseCustomColorFlags()
        return flags[eventId] ?? false
    }

    // MARK: - Private Storage Helpers

    private func getCustomColors() -> [String: String] {
        return defaults.dictionary(forKey: customColorsKey) as? [String: String] ?? [:]
    }

    private func saveCustomColors(_ colors: [String: String]) {
        defaults.set(colors, forKey: customColorsKey)
    }

    private func getUseCustomColorFlags() -> [String: Bool] {
        return defaults.dictionary(forKey: useCustomColorKey) as? [String: Bool] ?? [:]
    }

    private func saveUseCustomColorFlags(_ flags: [String: Bool]) {
        defaults.set(flags, forKey: useCustomColorKey)
    }
}

// MARK: - Color Extensions

extension Color {
    /// Convert Color to hex string
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else {
            return "#000000"
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}
