import SwiftUI
import MapKit

/// Comprehensive view for comparing travel options to an event
struct TravelOptionsView: View {
    let event: UnifiedEvent
    let destination: CLLocationCoordinate2D
    @StateObject private var travelManager = TravelTimeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var travelComparison: TravelComparison?
    @State private var isLoading = true
    @State private var selectedRoute: TravelRoute?
    @State private var showingRouteDetails = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Event Header
                    EventHeaderCard(event: event)

                    if isLoading {
                        LoadingView()
                    } else if let comparison = travelComparison {
                        // Routes Section
                        RoutesSection(
                            routes: comparison.routes,
                            selectedRoute: $selectedRoute,
                            onRouteSelected: { route in
                                selectedRoute = route
                                showingRouteDetails = true
                            }
                        )

                        // Ride-Share Section
                        if !comparison.rideShareEstimates.isEmpty {
                            RideShareSection(estimates: comparison.rideShareEstimates)
                        }

                        // Parking Section
                        if !comparison.parkingOptions.isEmpty {
                            ParkingSection(parkingOptions: comparison.parkingOptions, destination: destination)
                        }

                        // Quick Comparison
                        QuickComparisonCard(comparison: comparison)
                    } else {
                        EmptyStateView()
                    }
                }
                .padding()
            }
            .navigationTitle("Travel Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingRouteDetails) {
                if let route = selectedRoute {
                    RouteDetailsView(route: route, destination: destination)
                }
            }
            .onAppear {
                loadTravelOptions()
            }
        }
    }

    private func loadTravelOptions() {
        isLoading = true
        travelManager.getTravelComparison(to: destination) { comparison in
            self.travelComparison = comparison
            self.isLoading = false
        }
    }
}

// MARK: - Event Header Card

struct EventHeaderCard: View {
    let event: UnifiedEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .fontWeight(.semibold)

                    if let location = event.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(location)
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(event.startDate, style: .time)
                        .font(.title3)
                        .fontWeight(.bold)

                    Text(event.startDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Routes Section

struct RoutesSection: View {
    let routes: [TravelRoute]
    @Binding var selectedRoute: TravelRoute?
    let onRouteSelected: (TravelRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Routes")
                .font(.title2)
                .fontWeight(.bold)

            ForEach(routes) { route in
                RouteCard(route: route) {
                    onRouteSelected(route)
                }
            }
        }
    }
}

struct RouteCard: View {
    let route: TravelRoute
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: route.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(transportColor)
                    .clipShape(Circle())

                // Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        Label(route.travelTimeFormatted, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label(route.distanceFormatted, systemImage: "arrow.left.and.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if route.tollsExpected {
                        Label("Tolls", systemImage: "dollarsign.circle")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var transportColor: Color {
        switch route.transportType {
        case .automobile: return .blue
        case .walking: return .green
        case .transit: return .orange
        default: return .gray
        }
    }
}

// MARK: - Ride-Share Section

struct RideShareSection: View {
    let estimates: [RideShareEstimate]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ride-Share")
                .font(.title2)
                .fontWeight(.bold)

            ForEach(estimates) { estimate in
                RideShareCard(estimate: estimate)
            }

            Text("Prices are estimates and may vary based on demand")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
}

struct RideShareCard: View {
    let estimate: RideShareEstimate

    var body: some View {
        HStack(spacing: 16) {
            // Service Icon
            ZStack {
                Circle()
                    .fill(serviceColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Text(estimate.serviceName.prefix(1).uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(serviceColor)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text("\(estimate.serviceName) - \(estimate.productName)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    Text(estimate.priceRangeFormatted)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)

                    Label(estimate.pickupTimeFormatted, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                // Open ride-share app
                openRideShareApp(estimate.serviceName)
            }) {
                Text("Open")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(serviceColor)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var serviceColor: Color {
        switch estimate.serviceName.lowercased() {
        case "uber": return .black
        case "lyft": return .pink
        default: return .blue
        }
    }

    private func openRideShareApp(_ service: String) {
        // Would open the respective app with deep link
        print("Opening \(service) app...")
    }
}

// MARK: - Parking Section

struct ParkingSection: View {
    let parkingOptions: [ParkingInfo]
    let destination: CLLocationCoordinate2D

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parking Nearby")
                .font(.title2)
                .fontWeight(.bold)

            ForEach(parkingOptions) { parking in
                ParkingCard(parking: parking, destination: destination)
            }
        }
    }
}

struct ParkingCard: View {
    let parking: ParkingInfo
    let destination: CLLocationCoordinate2D

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "parkingsign.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(parking.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Label(parking.distanceFormatted + " from destination", systemImage: "arrow.left.and.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let priceRange = parking.priceRange {
                    Text(priceRange)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Spacer()

            Button(action: {
                openInMaps(coordinate: parking.coordinate, name: parking.name)
            }) {
                Image(systemName: "map")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = name
        mapItem.openInMaps(launchOptions: nil)
    }
}

// MARK: - Quick Comparison Card

struct QuickComparisonCard: View {
    let comparison: TravelComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Comparison")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                if let fastest = comparison.fastestRoute {
                    ComparisonRow(
                        icon: "clock.fill",
                        title: "Fastest Option",
                        value: "\(fastest.name) - \(fastest.travelTimeFormatted)",
                        color: .green
                    )
                }

                if let cheapest = comparison.cheapestRideShare {
                    ComparisonRow(
                        icon: "dollarsign.circle.fill",
                        title: "Cheapest Ride",
                        value: "\(cheapest.serviceName) - \(cheapest.priceRangeFormatted)",
                        color: .blue
                    )
                }

                if let closestParking = comparison.parkingOptions.first {
                    ComparisonRow(
                        icon: "parkingsign.circle.fill",
                        title: "Closest Parking",
                        value: "\(closestParking.name) - \(closestParking.distanceFormatted)",
                        color: .orange
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct ComparisonRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
    }
}

// MARK: - Route Details View

struct RouteDetailsView: View {
    let route: TravelRoute
    let destination: CLLocationCoordinate2D
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Route Summary
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: route.icon)
                                .font(.title)
                                .foregroundColor(.blue)

                            VStack(alignment: .leading) {
                                Text(route.name)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text(route.transportType == .automobile ? "Driving" : route.transportType == .walking ? "Walking" : "Public Transit")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }

                        HStack(spacing: 20) {
                            StatBox(icon: "clock.fill", title: "Duration", value: route.travelTimeFormatted)
                            StatBox(icon: "arrow.left.and.right", title: "Distance", value: route.distanceFormatted)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Directions
                    if !route.steps.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Directions")
                                .font(.headline)

                            ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
                                DirectionStepRow(stepNumber: index + 1, step: step)
                            }
                        }
                    }

                    // Advisories
                    if !route.advisories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Advisories")
                                .font(.headline)

                            ForEach(route.advisories, id: \.self) { advisory in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)

                                    Text(advisory)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Route Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        openInMaps()
                    }) {
                        Label("Open in Maps", systemImage: "map")
                    }
                }
            }
        }
    }

    private func openInMaps() {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

struct StatBox: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
    }
}

struct DirectionStepRow: View {
    let stepNumber: Int
    let step: RouteStep

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(stepNumber)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))

            VStack(alignment: .leading, spacing: 4) {
                Text(step.instruction)
                    .font(.subheadline)

                if step.distance > 0 {
                    let distanceFormatted = String(format: "%.1f mi", step.distance * 0.000621371)
                    Text(distanceFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Loading & Empty States

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Finding travel options...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Unable to load travel options")
                .font(.headline)

            Text("Make sure location services are enabled")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Preview

struct TravelOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEvent = UnifiedEvent(
            id: "sample",
            calendarId: "calendar",
            title: "Team Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            location: "Apple Park, Cupertino, CA",
            notes: nil,
            url: nil,
            isAllDay: false,
            source: .ios
        )

        TravelOptionsView(
            event: sampleEvent,
            destination: CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090)
        )
    }
}
