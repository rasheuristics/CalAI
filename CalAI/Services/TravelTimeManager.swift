import Foundation
import CoreLocation
import MapKit

class TravelTimeManager: NSObject, ObservableObject {
    static let shared = TravelTimeManager()

    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// Request location permission
    func requestLocationPermission() {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            print("🔵 Requesting location permission...")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location permission already granted")
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("❌ Location permission denied or restricted")
        @unknown default:
            print("⚠️ Unknown location authorization status")
        }
    }

    /// Calculate travel time from current location to destination
    func calculateTravelTime(
        to destinationCoordinate: CLLocationCoordinate2D,
        completion: @escaping (TimeInterval?, Error?) -> Void
    ) {
        guard let currentLocation = currentLocation else {
            print("❌ Current location not available")
            completion(nil, NSError(domain: "TravelTimeManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Current location not available"]))
            return
        }

        let sourcePlacemark = MKPlacemark(coordinate: currentLocation.coordinate)
        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        print("🔵 Calculating travel time from \(currentLocation.coordinate) to \(destinationCoordinate)...")

        directions.calculate { response, error in
            if let error = error {
                print("❌ Travel time calculation error: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            guard let route = response?.routes.first else {
                print("⚠️ No route found")
                completion(nil, NSError(domain: "TravelTimeManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No route found"]))
                return
            }

            let travelTime = route.expectedTravelTime
            let travelTimeMinutes = Int(travelTime / 60)
            print("✅ Travel time calculated: \(travelTimeMinutes) minutes (\(travelTime) seconds)")

            completion(travelTime, nil)
        }
    }

    /// Calculate when user should leave for a meeting
    func calculateDepartureTime(
        meetingStartTime: Date,
        destinationCoordinate: CLLocationCoordinate2D,
        bufferMinutes: Int,
        completion: @escaping (Date?, TimeInterval?) -> Void
    ) {
        calculateTravelTime(to: destinationCoordinate) { travelTime, error in
            guard let travelTime = travelTime else {
                print("⚠️ Could not calculate departure time: \(error?.localizedDescription ?? "unknown error")")
                completion(nil, nil)
                return
            }

            let totalTimeNeeded = travelTime + TimeInterval(bufferMinutes * 60)
            let departureTime = meetingStartTime.addingTimeInterval(-totalTimeNeeded)

            let travelMinutes = Int(travelTime / 60)
            let totalMinutes = Int(totalTimeNeeded / 60)

            print("✅ Should leave at \(departureTime.formatted(date: .omitted, time: .shortened))")
            print("   Travel time: \(travelMinutes) min + Buffer: \(bufferMinutes) min = Total: \(totalMinutes) min")

            completion(departureTime, travelTime)
        }
    }

    /// Start monitoring location updates
    func startMonitoring() {
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
            print("🔵 Started monitoring location")
        } else {
            print("⚠️ Cannot start monitoring - no location permission")
        }
    }

    /// Stop monitoring location updates
    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
        print("🔵 Stopped monitoring location")
    }
}

// MARK: - CLLocationManagerDelegate
extension TravelTimeManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .notDetermined:
            print("🔵 Location authorization: Not determined")
        case .restricted:
            print("❌ Location authorization: Restricted")
        case .denied:
            print("❌ Location authorization: Denied")
        case .authorizedAlways:
            print("✅ Location authorization: Always")
            locationManager.startUpdatingLocation()
        case .authorizedWhenInUse:
            print("✅ Location authorization: When in use")
            locationManager.startUpdatingLocation()
        @unknown default:
            print("⚠️ Location authorization: Unknown")
        }
    }
}
