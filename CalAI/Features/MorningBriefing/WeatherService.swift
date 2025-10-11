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

    // OpenWeatherMap API Key - Fallback for iOS 15 only
    private var apiKey: String? {
        get {
            return UserDefaults.standard.string(forKey: "openWeatherMapAPIKey")
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

    /// Fetch current weather for device location
    func fetchCurrentWeather(completion: @escaping (Result<WeatherData, Error>) -> Void) {
        // Check location authorization
        let status = locationManager.authorizationStatus
        print("🌦️ WeatherService: Checking location authorization - status: \(status.rawValue)")

        switch status {
        case .notDetermined:
            // Request permission
            print("⚠️ WeatherService: Location permission not determined, requesting...")
            locationManager.requestWhenInUseAuthorization()
            let error = NSError(domain: "WeatherService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Location permission not granted"
            ])
            completion(.failure(error))

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
        isLoading = true
        error = nil

        // Try WeatherKit first (iOS 16+)
        if #available(iOS 16.0, *) {
            print("🌦️ WeatherService: Using WeatherKit (iOS 16+)")
            fetchWeatherKitData(for: location)
        } else {
            print("🌦️ WeatherService: Using OpenWeatherMap fallback (iOS 15)")
            // Fallback to OpenWeatherMap for iOS 15
            fetchOpenWeatherMapData(for: location)
        }
    }

    // MARK: - WeatherKit Implementation (iOS 16+)

    @available(iOS 16.0, *)
    private func fetchWeatherKitData(for location: CLLocation) {
        Task {
            do {
                print("🌦️ WeatherService: Requesting weather from WeatherKit...")
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
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = "WeatherKit error: \(error.localizedDescription)"
                    self.weatherCompletion?(.failure(error))
                    self.weatherCompletion = nil
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
                    self.error = error.localizedDescription
                    self.weatherCompletion?(.failure(error))
                    self.weatherCompletion = nil
                    return
                }

                guard let data = data else {
                    let error = NSError(domain: "WeatherService", code: 6, userInfo: [
                        NSLocalizedDescriptionKey: "No weather data received"
                    ])
                    self.error = error.localizedDescription
                    self.weatherCompletion?(.failure(error))
                    self.weatherCompletion = nil
                    return
                }

                do {
                    let weatherResponse = try JSONDecoder().decode(OpenWeatherMapResponse.self, from: data)
                    let weatherData = self.convertOpenWeatherToWeatherData(weatherResponse)
                    self.currentWeather = weatherData
                    self.weatherCompletion?(.success(weatherData))
                    self.weatherCompletion = nil
                } catch {
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
