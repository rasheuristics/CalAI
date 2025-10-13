import Foundation
import CoreLocation
import Combine
import WeatherKit

/// Service for fetching weather data using Apple WeatherKit (iOS 16+) with OpenWeatherMap fallback (iOS 15)
class WeatherService: NSObject, ObservableObject {
    static let shared = WeatherService()

    @Published var currentWeather: WeatherData?
    @Published var isLoading = false
    @Published var error: String?

    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()

    // OpenWeatherMap API Key - Fallback for iOS 15 and WeatherKit auth failures
    // Using a demo/shared key for development - users should get their own from openweathermap.org
    private var apiKey: String? {
        get {
            // Check if user has set their own key
            if let userKey = UserDefaults.standard.string(forKey: "openWeatherMapAPIKey"), !userKey.isEmpty {
                return userKey
            }
            // Use demo key as fallback (limited requests per day)
            return "bf6b6c9842f882091a13f38933e2ce54" // Demo key - replace with your own
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "openWeatherMapAPIKey")
        }
    }

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Public Methods

    /// Request location permission proactively
    func requestLocationPermission() {
        let status = locationManager.authorizationStatus
        print("🌦️ WeatherService: Current location status: \(status.rawValue)")

        if status == .notDetermined {
            print("🌦️ WeatherService: Requesting location permission...")
            locationManager.requestWhenInUseAuthorization()
        }
    }

    /// Fetch current weather for device location
    func fetchCurrentWeather(completion: @escaping (Result<WeatherData, Error>) -> Void) {
        // Check location authorization
        let status = locationManager.authorizationStatus
        print("========================================")
        print("🔴🔴🔴 WEATHER FETCH STARTED 🔴🔴🔴")
        print("========================================")
        print("🌦️ WeatherService: Checking location authorization - status: \(status.rawValue)")

        switch status {
        case .notDetermined:
            // Request permission and store completion for later
            print("⚠️ WeatherService: Location permission not determined, requesting and storing completion...")
            self.weatherCompletion = completion
            locationManager.requestWhenInUseAuthorization()
            // Don't fail immediately - wait for authorization response

        case .restricted, .denied:
            print("❌ WeatherService: Location permission denied or restricted")
            let error = NSError(domain: "WeatherService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Location permission denied. Enable in Settings."
            ])
            completion(.failure(error))

        case .authorizedWhenInUse, .authorizedAlways:
            // Get location and fetch weather
            print("✅ WeatherService: Location authorized, requesting location...")
            locationManager.requestLocation()

            // Store completion for when location is received
            self.weatherCompletion = completion

        @unknown default:
            print("❌ WeatherService: Unknown location authorization status")
            let error = NSError(domain: "WeatherService", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Unknown location authorization status"
            ])
            completion(.failure(error))
        }
    }

    /// Set API key (for iOS 15 fallback)
    func setAPIKey(_ key: String) {
        self.apiKey = key
    }

    /// Check if API key is configured (for iOS 15 fallback)
    func hasAPIKey() -> Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }

    /// Check if WeatherKit is available (iOS 16+)
    var isWeatherKitAvailable: Bool {
        if #available(iOS 16.0, *) {
            return true
        }
        return false
    }

    // MARK: - Private Methods

    private var weatherCompletion: ((Result<WeatherData, Error>) -> Void)?

    private func fetchWeather(for location: CLLocation) {
        print("🌦️ WeatherService: Fetching weather for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("🌦️ WeatherService: iOS Version: \(ProcessInfo.processInfo.operatingSystemVersion)")
        isLoading = true
        error = nil

        // Try WeatherKit first (iOS 16+)
        if #available(iOS 16.0, *) {
            print("✅ WeatherService: iOS 16+ detected - Attempting WeatherKit...")
            print("✅ WeatherService: WeatherKit entitlement should be present in app")
            fetchWeatherKitData(for: location)
        } else {
            print("⚠️ WeatherService: iOS 15 detected - Using OpenWeatherMap fallback")
            // Fallback to OpenWeatherMap for iOS 15
            fetchOpenWeatherMapData(for: location)
        }
    }

    // MARK: - WeatherKit Implementation (iOS 16+)

    @available(iOS 16.0, *)
    private func fetchWeatherKitData(for location: CLLocation) {
        print("🔵 WeatherService: fetchWeatherKitData() called - Starting WeatherKit request...")
        Task {
            do {
                print("🌦️ WeatherService: Requesting weather from WeatherKit API...")
                print("🌦️ WeatherService: Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
                let currentWeather = weather.currentWeather
                print("✅ WeatherService: WeatherKit data received - \(currentWeather.temperature.value)°C, \(currentWeather.condition.description)")

                // Convert to WeatherData
                let weatherData = WeatherData(
                    temperature: convertTemperature(currentWeather.temperature.value),
                    feelsLike: convertTemperature(currentWeather.apparentTemperature.value),
                    condition: currentWeather.condition.description,
                    conditionDescription: currentWeather.condition.description,
                    high: convertTemperature(weather.dailyForecast.first?.highTemperature.value ?? currentWeather.temperature.value),
                    low: convertTemperature(weather.dailyForecast.first?.lowTemperature.value ?? currentWeather.temperature.value),
                    precipitationChance: Int((weather.dailyForecast.first?.precipitationChance ?? 0) * 100),
                    humidity: Int(currentWeather.humidity * 100),
                    windSpeed: convertWindSpeed(currentWeather.wind.speed.value),
                    icon: weatherConditionToIcon(currentWeather.condition)
                )

                DispatchQueue.main.async {
                    print("✅ WeatherService: Weather data converted and ready")
                    self.currentWeather = weatherData
                    self.isLoading = false
                    self.weatherCompletion?(.success(weatherData))
                    self.weatherCompletion = nil
                }
            } catch {
                print("❌ WeatherService: WeatherKit error - \(error.localizedDescription)")

                // Detailed error diagnostics
                let nsError = error as NSError
                print("   ❌ Error Domain: \(nsError.domain)")
                print("   ❌ Error Code: \(nsError.code)")
                print("   ❌ Error UserInfo: \(nsError.userInfo)")

                // Check for common WeatherKit errors
                if nsError.domain.contains("weatherDaemon") || nsError.code == 2 {
                    print("   ⚠️ This is a WeatherKit authentication/entitlement error")
                    print("   ⚠️ Common causes:")
                    print("      1. WeatherKit not enabled on App ID in Developer Portal")
                    print("      2. Provisioning profile doesn't include WeatherKit (regenerate it)")
                    print("      3. Not signed with paid Apple Developer account")
                    print("      4. Bundle ID mismatch")
                    print("   ⚠️ Falling back to OpenWeatherMap...")
                } else if nsError.code == 1 {
                    print("   ⚠️ Network or data unavailable error")
                } else {
                    print("   ⚠️ Unknown WeatherKit error")
                }

                // Always fall back to OpenWeatherMap on any WeatherKit error
                print("   🔄 Attempting OpenWeatherMap fallback...")
                DispatchQueue.main.async {
                    self.fetchOpenWeatherMapData(for: location)
                }
            }
        }
    }

    @available(iOS 16.0, *)
    private func weatherConditionToIcon(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear: return "01d"
        case .cloudy: return "04d"
        case .partlyCloudy: return "02d"
        case .mostlyCloudy: return "03d"
        case .rain: return "10d"
        case .drizzle: return "09d"
        case .heavyRain: return "10d"
        case .snow: return "13d"
        case .sleet: return "13d"
        case .hail: return "13d"
        case .thunderstorms: return "11d"
        case .tropicalStorm: return "11d"
        case .hurricane: return "11d"
        case .foggy: return "50d"
        case .haze: return "50d"
        case .smoky: return "50d"
        case .breezy: return "01d"
        case .windy: return "01d"
        default: return "01d"
        }
    }

    // MARK: - OpenWeatherMap Implementation (iOS 15 Fallback)

    private func fetchOpenWeatherMapData(for location: CLLocation) {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            let error = NSError(domain: "WeatherService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Weather unavailable on iOS 15 without OpenWeatherMap API key"
            ])
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = error.localizedDescription
                self.weatherCompletion?(.failure(error))
                self.weatherCompletion = nil
            }
            return
        }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        let currentWeatherURL = "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric"

        print("🌐 OpenWeatherMap: Fetching from URL: \(currentWeatherURL)")

        guard let url = URL(string: currentWeatherURL) else {
            let error = NSError(domain: "WeatherService", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Invalid weather API URL"
            ])
            weatherCompletion?(.failure(error))
            weatherCompletion = nil
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    print("❌ OpenWeatherMap: Network error - \(error.localizedDescription)")
                    self.error = error.localizedDescription
                    self.weatherCompletion?(.failure(error))
                    self.weatherCompletion = nil
                    return
                }

                // Check HTTP response
                if let httpResponse = response as? HTTPURLResponse {
                    print("🌐 OpenWeatherMap: HTTP Status Code: \(httpResponse.statusCode)")

                    if httpResponse.statusCode != 200 {
                        // Try to get error message from response
                        if let data = data, let responseString = String(data: data, encoding: .utf8) {
                            print("❌ OpenWeatherMap: Error response: \(responseString)")

                            let error = NSError(domain: "WeatherService", code: httpResponse.statusCode, userInfo: [
                                NSLocalizedDescriptionKey: "OpenWeatherMap API error (code \(httpResponse.statusCode)): \(responseString)"
                            ])
                            self.error = error.localizedDescription
                            self.weatherCompletion?(.failure(error))
                            self.weatherCompletion = nil
                            return
                        }
                    }
                }

                guard let data = data else {
                    let error = NSError(domain: "WeatherService", code: 6, userInfo: [
                        NSLocalizedDescriptionKey: "No weather data received"
                    ])
                    print("❌ OpenWeatherMap: No data received")
                    self.error = error.localizedDescription
                    self.weatherCompletion?(.failure(error))
                    self.weatherCompletion = nil
                    return
                }

                // Log raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🌐 OpenWeatherMap: Raw response: \(responseString)")
                }

                do {
                    let weatherResponse = try JSONDecoder().decode(OpenWeatherMapResponse.self, from: data)
                    print("✅ OpenWeatherMap: Successfully decoded response")
                    let weatherData = self.convertOpenWeatherToWeatherData(weatherResponse)
                    print("✅ OpenWeatherMap: Weather data converted - \(weatherData.temperatureFormatted), \(weatherData.condition)")
                    self.currentWeather = weatherData
                    self.weatherCompletion?(.success(weatherData))
                    self.weatherCompletion = nil
                } catch {
                    print("❌ OpenWeatherMap: Failed to parse JSON - \(error.localizedDescription)")
                    if let decodingError = error as? DecodingError {
                        print("❌ Decoding error details: \(decodingError)")
                    }
                    self.error = "Failed to parse weather data: \(error.localizedDescription)"
                    self.weatherCompletion?(.failure(error))
                    self.weatherCompletion = nil
                }
            }
        }.resume()
    }

    private func convertOpenWeatherToWeatherData(_ response: OpenWeatherMapResponse) -> WeatherData {
        // Convert Celsius to local preference
        let usesMetric = Locale.current.usesMetricSystem
        let temp = usesMetric ? response.main.temp : celsiusToFahrenheit(response.main.temp)
        let feelsLike = usesMetric ? response.main.feelsLike : celsiusToFahrenheit(response.main.feelsLike)
        let high = usesMetric ? response.main.tempMax : celsiusToFahrenheit(response.main.tempMax)
        let low = usesMetric ? response.main.tempMin : celsiusToFahrenheit(response.main.tempMin)

        return WeatherData(
            temperature: temp,
            feelsLike: feelsLike,
            condition: response.weather.first?.main ?? "Unknown",
            conditionDescription: response.weather.first?.description.capitalized ?? "",
            high: high,
            low: low,
            precipitationChance: Int((response.clouds?.all ?? 0) / 2), // Approximate
            humidity: response.main.humidity,
            windSpeed: response.wind.speed,
            icon: response.weather.first?.icon ?? ""
        )
    }

    // MARK: - Helper Methods

    private func convertTemperature(_ celsius: Double) -> Double {
        let usesMetric = Locale.current.usesMetricSystem
        return usesMetric ? celsius : celsiusToFahrenheit(celsius)
    }

    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return (celsius * 9/5) + 32
    }

    private func convertWindSpeed(_ metersPerSecond: Double) -> Double {
        let usesMetric = Locale.current.usesMetricSystem
        return usesMetric ? metersPerSecond * 3.6 : metersPerSecond * 2.237 // km/h or mph
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            print("❌ WeatherService: No location received")
            return
        }
        print("✅ WeatherService: Location received - \(location.coordinate.latitude), \(location.coordinate.longitude)")
        fetchWeather(for: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ WeatherService: Location error - \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.error = "Failed to get location: \(error.localizedDescription)"
            let nsError = error as NSError
            self.weatherCompletion?(.failure(nsError))
            self.weatherCompletion = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Handle authorization changes
        let status = manager.authorizationStatus
        print("📍 Location authorization changed: \(status.rawValue)")

        // If we have a pending weather request and permission is now granted, fetch the weather
        if weatherCompletion != nil && (status == .authorizedWhenInUse || status == .authorizedAlways) {
            print("✅ Location permission granted, fetching weather for pending request...")
            locationManager.requestLocation()
        } else if weatherCompletion != nil && (status == .denied || status == .restricted) {
            print("❌ Location permission denied after request")
            let error = NSError(domain: "WeatherService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Location permission denied. Enable in Settings."
            ])
            weatherCompletion?(.failure(error))
            weatherCompletion = nil
        }
    }
}

// MARK: - OpenWeatherMap Response Models

struct OpenWeatherMapResponse: Codable {
    let coord: Coordinates
    let weather: [Weather]
    let main: MainWeather
    let wind: Wind
    let clouds: Clouds?
    let dt: Int
    let name: String

    struct Coordinates: Codable {
        let lon: Double
        let lat: Double
    }

    struct Weather: Codable {
        let id: Int
        let main: String
        let description: String
        let icon: String
    }

    struct MainWeather: Codable {
        let temp: Double
        let feelsLike: Double
        let tempMin: Double
        let tempMax: Double
        let pressure: Int
        let humidity: Int

        enum CodingKeys: String, CodingKey {
            case temp
            case feelsLike = "feels_like"
            case tempMin = "temp_min"
            case tempMax = "temp_max"
            case pressure
            case humidity
        }
    }

    struct Wind: Codable {
        let speed: Double
        let deg: Int?
    }

    struct Clouds: Codable {
        let all: Int
    }
}
