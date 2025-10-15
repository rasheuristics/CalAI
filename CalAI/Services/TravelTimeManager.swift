import Foundation
import CoreLocation
import MapKit

// MARK: - Travel Route Models

struct TravelRoute: Identifiable {
    let id = UUID()
    let name: String
    let transportType: MKDirectionsTransportType
    let travelTime: TimeInterval
    let distance: Double // in meters
    let steps: [RouteStep]
    let polyline: MKPolyline?
    let advisories: [String]
    let tollsExpected: Bool

    var travelTimeFormatted: String {
        let minutes = Int(travelTime / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes) min"
        }
    }

    var distanceFormatted: String {
        let miles = distance * 0.000621371
        return String(format: "%.1f mi", miles)
    }

    var icon: String {
        switch transportType {
        case .automobile: return "car.fill"
        case .walking: return "figure.walk"
        case .transit: return "bus.fill"
        default: return "mappin.circle.fill"
        }
    }
}

struct RouteStep {
    let instruction: String
    let distance: Double
    let polyline: MKPolyline?
}

struct ParkingInfo: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let distanceFromDestination: Double // in meters
    let estimatedSpaces: Int?
    let priceRange: String?

    var distanceFormatted: String {
        let feet = distanceFromDestination * 3.28084
        if feet < 1000 {
            return "\(Int(feet)) ft"
        } else {
            let miles = distanceFromDestination * 0.000621371
            return String(format: "%.1f mi", miles)
        }
    }
}

struct RideShareEstimate: Identifiable {
    let id = UUID()
    let serviceName: String
    let productName: String
    let estimatedPrice: (low: Double, high: Double)
    let estimatedPickupTime: TimeInterval
    let estimatedDuration: TimeInterval

    var priceRangeFormatted: String {
        return String(format: "$%.0f - $%.0f", estimatedPrice.low, estimatedPrice.high)
    }

    var pickupTimeFormatted: String {
        let minutes = Int(estimatedPickupTime / 60)
        return "\(minutes) min"
    }

    var icon: String {
        switch serviceName.lowercased() {
        case "uber": return "u.circle.fill"
        case "lyft": return "l.circle.fill"
        default: return "car.circle.fill"
        }
    }
}

struct TravelComparison {
    let routes: [TravelRoute]
    let parkingOptions: [ParkingInfo]
    let rideShareEstimates: [RideShareEstimate]

    var fastestRoute: TravelRoute? {
        routes.min(by: { $0.travelTime < $1.travelTime })
    }

    var cheapestRideShare: RideShareEstimate? {
        rideShareEstimates.min(by: { $0.estimatedPrice.low < $1.estimatedPrice.low })
    }
}

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

    // MARK: - Enhanced Travel Options

    /// Get comprehensive travel comparison with multiple routes and options
    func getTravelComparison(
        to destination: CLLocationCoordinate2D,
        completion: @escaping (TravelComparison?) -> Void
    ) {
        guard currentLocation != nil else {
            print("❌ Current location not available")
            completion(nil)
            return
        }

        let group = DispatchGroup()
        var routes: [TravelRoute] = []
        var parkingOptions: [ParkingInfo] = []
        var rideShareEstimates: [RideShareEstimate] = []

        // Get driving routes
        group.enter()
        getMultipleRoutes(to: destination, transportType: .automobile) { drivingRoutes in
            routes.append(contentsOf: drivingRoutes)
            group.leave()
        }

        // Get transit routes
        group.enter()
        getMultipleRoutes(to: destination, transportType: .transit) { transitRoutes in
            routes.append(contentsOf: transitRoutes)
            group.leave()
        }

        // Get walking route
        group.enter()
        getMultipleRoutes(to: destination, transportType: .walking) { walkingRoutes in
            routes.append(contentsOf: walkingRoutes)
            group.leave()
        }

        // Find parking near destination
        group.enter()
        findParkingNearDestination(destination) { parking in
            parkingOptions = parking
            group.leave()
        }

        // Get ride-share estimates
        group.enter()
        getRideShareEstimates(to: destination) { estimates in
            rideShareEstimates = estimates
            group.leave()
        }

        group.notify(queue: .main) {
            let comparison = TravelComparison(
                routes: routes,
                parkingOptions: parkingOptions,
                rideShareEstimates: rideShareEstimates
            )
            completion(comparison)
        }
    }

    /// Get multiple route options for a specific transport type
    func getMultipleRoutes(
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType,
        completion: @escaping ([TravelRoute]) -> Void
    ) {
        guard let currentLocation = currentLocation else {
            completion([])
            return
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: currentLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportType
        request.requestsAlternateRoutes = true

        let directions = MKDirections(request: request)

        directions.calculate { response, error in
            if let error = error {
                print("❌ Route calculation error for \(transportType): \(error.localizedDescription)")
                completion([])
                return
            }

            guard let mkRoutes = response?.routes else {
                completion([])
                return
            }

            let routes = mkRoutes.enumerated().map { index, mkRoute in
                let steps = mkRoute.steps.map { step in
                    RouteStep(
                        instruction: step.instructions,
                        distance: step.distance,
                        polyline: step.polyline
                    )
                }

                let routeName: String
                switch transportType {
                case .automobile:
                    routeName = index == 0 ? "Fastest Route" : "Alternate Route \(index)"
                case .transit:
                    routeName = "Public Transit"
                case .walking:
                    routeName = "Walking"
                default:
                    routeName = "Route \(index + 1)"
                }

                return TravelRoute(
                    name: routeName,
                    transportType: transportType,
                    travelTime: mkRoute.expectedTravelTime,
                    distance: mkRoute.distance,
                    steps: steps,
                    polyline: mkRoute.polyline,
                    advisories: mkRoute.advisoryNotices,
                    tollsExpected: !mkRoute.hasTolls
                )
            }

            completion(routes)
        }
    }

    /// Find parking options near destination
    func findParkingNearDestination(
        _ destination: CLLocationCoordinate2D,
        completion: @escaping ([ParkingInfo]) -> Void
    ) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = "parking"
        searchRequest.region = MKCoordinateRegion(
            center: destination,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )

        let search = MKLocalSearch(request: searchRequest)

        search.start { response, error in
            if let error = error {
                print("❌ Parking search error: \(error.localizedDescription)")
                completion([])
                return
            }

            guard let mapItems = response?.mapItems else {
                completion([])
                return
            }

            let parkingOptions = mapItems.prefix(5).map { item in
                let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
                let parkingLocation = CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
                let distance = parkingLocation.distance(from: destinationLocation)

                return ParkingInfo(
                    name: item.name ?? "Parking",
                    coordinate: item.placemark.coordinate,
                    distanceFromDestination: distance,
                    estimatedSpaces: nil, // Would need external API
                    priceRange: nil // Would need external API
                )
            }

            completion(Array(parkingOptions))
        }
    }

    /// Estimate ride-share costs (mock implementation - would need Uber/Lyft API integration)
    func getRideShareEstimates(
        to destination: CLLocationCoordinate2D,
        completion: @escaping ([RideShareEstimate]) -> Void
    ) {
        guard let currentLocation = currentLocation else {
            completion([])
            return
        }

        // Calculate distance for estimation
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let distance = currentLocation.distance(from: destinationLocation)
        let distanceMiles = distance * 0.000621371

        // Mock estimates based on distance (in real app, would use Uber/Lyft APIs)
        let baseRate = 2.50
        let perMileRate = 1.75
        let estimatedCost = baseRate + (distanceMiles * perMileRate)

        let estimates = [
            RideShareEstimate(
                serviceName: "Uber",
                productName: "UberX",
                estimatedPrice: (low: estimatedCost * 0.9, high: estimatedCost * 1.2),
                estimatedPickupTime: 300, // 5 minutes
                estimatedDuration: distance / 10 // rough estimate
            ),
            RideShareEstimate(
                serviceName: "Uber",
                productName: "Uber Comfort",
                estimatedPrice: (low: estimatedCost * 1.2, high: estimatedCost * 1.5),
                estimatedPickupTime: 360, // 6 minutes
                estimatedDuration: distance / 10
            ),
            RideShareEstimate(
                serviceName: "Lyft",
                productName: "Lyft",
                estimatedPrice: (low: estimatedCost * 0.85, high: estimatedCost * 1.15),
                estimatedPickupTime: 300, // 5 minutes
                estimatedDuration: distance / 10
            )
        ]

        completion(estimates)
    }

    /// Create a travel time calendar block
    func createTravelTimeBlock(
        eventTitle: String,
        destination: CLLocationCoordinate2D,
        arrivalTime: Date,
        bufferMinutes: Int = 10
    ) async -> (startTime: Date, endTime: Date, travelTime: TimeInterval)? {
        guard let currentLocation = currentLocation else {
            print("❌ Current location not available")
            return nil
        }

        // Get the fastest route
        return await withCheckedContinuation { continuation in
            getTravelComparison(to: destination) { comparison in
                guard let fastestRoute = comparison?.fastestRoute else {
                    continuation.resume(returning: nil)
                    return
                }

                let travelTime = fastestRoute.travelTime
                let totalTimeNeeded = travelTime + TimeInterval(bufferMinutes * 60)
                let departureTime = arrivalTime.addingTimeInterval(-totalTimeNeeded)

                continuation.resume(returning: (
                    startTime: departureTime,
                    endTime: arrivalTime,
                    travelTime: travelTime
                ))
            }
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
