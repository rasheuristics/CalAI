//
//  SharedWeatherData.swift
//  MorningBriefingWidget
//
//  Shared data structures for the widget extension
//  Created by Belachew Tessema on 11/7/25.
//

import Foundation

/// Weather data structure shared between app and widget
struct WeatherData: Codable {
    let temperature: Double
    let feelsLike: Double
    let condition: String
    let conditionDescription: String
    let high: Double
    let low: Double
    let precipitationChance: Int
    let humidity: Int
    let windSpeed: Double
    let icon: String

    var temperatureFormatted: String {
        return String(format: "%.0f°", temperature)
    }

    var highLowFormatted: String {
        return String(format: "H:%.0f° L:%.0f°", high, low)
    }
}

/// Shared storage for weather data between app and widget
class SharedWeatherStorage {
    static let shared = SharedWeatherStorage()

    private let groupIdentifier = "group.com.rasheuristics.calendarweaver"
    private let weatherKey = "shared.weather.data"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: groupIdentifier)
    }

    private init() {}

    /// Load weather data from shared storage
    func loadWeather() -> WeatherData? {
        guard let userDefaults = userDefaults else {
            return nil
        }

        guard let data = userDefaults.data(forKey: weatherKey) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let weatherData = try decoder.decode(WeatherData.self, from: data)
            return weatherData
        } catch {
            return nil
        }
    }
}
