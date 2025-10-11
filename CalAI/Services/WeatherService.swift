import Foundation
import CoreLocation
import Combine

/// Service for fetching weather data using OpenWeatherMap API
class WeatherService: NSObject, ObservableObject {
    static let shared = WeatherService()

    @Published var currentWeather: WeatherData?
    @Published var isLoading = false
    @Published var error: String?

    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()

    // OpenWeatherMap API Key - Store in UserDefaults (user will provide in settings)
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
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            let error = NSError(domain: "WeatherService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "OpenWeatherMap API key not configured"
            ])
            completion(.failure(error))
            return
        }

        // Check location authorization
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            // Request permission
            locationManager.requestWhenInUseAuthorization()
            let error = NSError(domain: "WeatherService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Location permission not granted"
            ])
            completion(.failure(error))

        case .restricted, .denied:
            let error = NSError(domain: "WeatherService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Location permission denied. Enable in Settings."
            ])
            completion(.failure(error))

        case .authorizedWhenInUse, .authorizedAlways:
            // Get location and fetch weather
            locationManager.requestLocation()

            // Store completion for when location is received
            self.weatherCompletion = completion

        @unknown default:
            let error = NSError(domain: "WeatherService", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Unknown location authorization status"
            ])
            completion(.failure(error))
        }
    }

    /// Set API key
    func setAPIKey(_ key: String) {
        self.apiKey = key
    }

    /// Check if API key is configured
    func hasAPIKey() -> Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }

    // MARK: - Private Methods

    private var weatherCompletion: ((Result<WeatherData, Error>) -> Void)?

    private func fetchWeather(for location: CLLocation) {
        guard let apiKey = apiKey else { return }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        // OpenWeatherMap One Call API 3.0 (includes current + forecast)
        // Note: For free tier, use Current Weather API + 5-day forecast
        let currentWeatherURL = "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric"
        let forecastURL = "https://api.openweathermap.org/data/2.5/forecast?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric"

        isLoading = true
        error = nil

        // Fetch current weather
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
                    let weatherData = self.convertToWeatherData(weatherResponse)
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

    private func convertToWeatherData(_ response: OpenWeatherMapResponse) -> WeatherData {
        // Convert Celsius to Fahrenheit if needed (based on locale)
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

    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return (celsius * 9/5) + 32
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        fetchWeather(for: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
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
