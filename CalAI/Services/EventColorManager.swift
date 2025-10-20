import Foundation
import SwiftUI

/// Manages custom colors for events based on title
class EventColorManager: ObservableObject {
    static let shared = EventColorManager()

    private let defaults = UserDefaults.standard
    private let titleColorsKey = "eventTitleColors" // Changed from customColorsKey
    private let customColorsKey = "eventCustomColors" // Keep for migration
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

    private init() {
        migrateLegacyColors()
    }

    // MARK: - Migration

    /// Migrate old eventId-based colors to title-based colors
    private func migrateLegacyColors() {
        // This is a one-time migration - old eventId colors are no longer used
        // New system uses event titles for consistent coloring
    }

    // MARK: - Title-Based Color Management

    /// Get color for an event title (automatic assignment)
    func getColorForTitle(_ title: String) -> Color {
        // Check if user has set a custom color for this title
        if let customColor = getTitleColor(for: title) {
            return customColor
        }

        // Generate consistent color based on title hash
        return generateColorFromTitle(title)
    }

    /// Set a custom color for an event title
    func setTitleColor(_ color: Color, for title: String) {
        objectWillChange.send()
        var colors = getTitleColors()
        colors[title] = color.toHex()
        saveTitleColors(colors)
    }

    /// Get custom color for a title (if set by user)
    func getTitleColor(for title: String) -> Color? {
        let colors = getTitleColors()
        guard let hexString = colors[title] else { return nil }
        return Color(hex: hexString)
    }

    /// Remove custom color for a title
    func removeTitleColor(for title: String) {
        objectWillChange.send()
        var colors = getTitleColors()
        colors.removeValue(forKey: title)
        saveTitleColors(colors)
    }

    /// Check if title has custom color
    func hasTitleColor(for title: String) -> Bool {
        let colors = getTitleColors()
        return colors[title] != nil
    }

    // MARK: - Event-Specific Color Override (for individual events with same title)

    /// Set a custom color for a specific event (overrides title-based color)
    func setCustomColor(_ color: Color, for eventId: String) {
        objectWillChange.send()
        var colors = getCustomColors()
        colors[eventId] = color.toHex()
        saveCustomColors(colors)
    }

    /// Get custom color for a specific event
    func getCustomColor(for eventId: String) -> Color? {
        let colors = getCustomColors()
        guard let hexString = colors[eventId] else { return nil }
        return Color(hex: hexString)
    }

    /// Remove custom color for a specific event
    func removeCustomColor(for eventId: String) {
        objectWillChange.send()
        var colors = getCustomColors()
        colors.removeValue(forKey: eventId)
        saveCustomColors(colors)
    }

    /// Check if event has custom color override
    func hasCustomColor(for eventId: String) -> Bool {
        let colors = getCustomColors()
        return colors[eventId] != nil
    }

    /// Get final color for an event (checks custom > title-based > default)
    func getColor(for eventId: String, title: String, defaultColor: Color?) -> Color {
        // 1. Check if this specific event has a custom color
        if let customColor = getCustomColor(for: eventId) {
            return customColor
        }

        // 2. Check if the title has a custom color
        if let titleColor = getTitleColor(for: title) {
            return titleColor
        }

        // 3. Use automatic title-based color (ignore calendar color)
        return generateColorFromTitle(title)
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

    private func getTitleColors() -> [String: String] {
        return defaults.dictionary(forKey: titleColorsKey) as? [String: String] ?? [:]
    }

    private func saveTitleColors(_ colors: [String: String]) {
        defaults.set(colors, forKey: titleColorsKey)
    }

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

    // MARK: - Color Generation

    /// Generate a consistent color based on title hash
    private func generateColorFromTitle(_ title: String) -> Color {
        // Use hash to consistently assign the same color to the same title
        let hash = abs(title.hashValue)
        let colorIndex = hash % Self.predefinedColors.count
        return Self.predefinedColors[colorIndex]
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
