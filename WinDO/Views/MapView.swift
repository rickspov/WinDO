import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var selectedAirport: Airport?
    @State private var selectedFlight: FlightRadarService.FlightData?
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 18.7357, longitude: -70.1627),
            span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
        )
    )
    
    var body: some View {
        Map(position: $cameraPosition, selection: $selectedAirport) {
            // Airports
            ForEach(Airport.dominicanAirports) { airport in
                Annotation(
                    airport.name,
                    coordinate: CLLocationCoordinate2D(
                        latitude: airport.latitude,
                        longitude: airport.longitude
                    ),
                    anchor: .bottom
                ) {
                    AirportMarkerView(airport: airport, windData: viewModel.windData[airport.id])
                }
                .tag(airport)
            }
            
            // Flights
            ForEach(viewModel.flights) { flight in
                Annotation(
                    flight.callsign,
                    coordinate: CLLocationCoordinate2D(
                        latitude: flight.latitude,
                        longitude: flight.longitude
                    ),
                    anchor: .center
                ) {
                    FlightMarkerView(flight: flight)
                }
                .tag(flight)
            }
        }
        .overlay(alignment: .bottom) {
            if let airport = selectedAirport,
               let windData = viewModel.windData[airport.id] {
                AirportDetailCard(airport: airport, windData: windData)
                    .padding()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .gesture(
                        DragGesture()
                            .onEnded { gesture in
                                if gesture.translation.height > 50 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedAirport = nil
                                    }
                                }
                            }
                    )
            } else if let flight = selectedFlight {
                FlightDetailCard(flight: flight)
                    .padding()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .gesture(
                        DragGesture()
                            .onEnded { gesture in
                                if gesture.translation.height > 50 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedFlight = nil
                                    }
                                }
                            }
                    )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedAirport)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedFlight)
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    if gesture.translation.width > 100 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            // Handle back navigation
                            if selectedAirport != nil {
                                selectedAirport = nil
                            } else if selectedFlight != nil {
                                selectedFlight = nil
                            }
                        }
                    }
                }
        )
        .onAppear {
            Task {
                await viewModel.fetchAllWindData()
                await viewModel.startFlightTracking()
            }
        }
    }
}

// Flight marker
struct FlightMarkerView: View {
    let flight: FlightRadarService.FlightData
    
    var body: some View {
        Image(systemName: "airplane")
            .rotationEffect(.degrees(flight.heading))
            .foregroundColor(.white)
            .background(
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
            )
    }
}

// Flight detail card
struct FlightDetailCard: View {
    let flight: FlightRadarService.FlightData
    
    var body: some View {
        VStack(spacing: 12) {
            Text(flight.callsign)
                .font(.headline)
            
            HStack(spacing: 20) {
                FlightInfoItem(title: "Altitude", value: "\(flight.altitude) ft")
                FlightInfoItem(title: "Speed", value: "\(flight.speed) kts")
                FlightInfoItem(title: "Aircraft", value: flight.aircraft)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.ultraThinMaterial)
        )
        .shadow(radius: 5)
    }
}

struct FlightInfoItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .rounded))
        }
    }
}

// Add this after FlightDetailCard
struct AirportDetailCard: View {
    let airport: Airport
    let windData: WindData
    @State private var isAppearing = false
    
    var body: some View {
        VStack(spacing: 16) {  // Increased spacing for better readability
            Text(airport.name)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text(airport.city)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: 24) {  // Increased spacing between items
                DetailItem(title: "Direction", value: "\(Int(windData.direction))°")
                DetailItem(title: "Speed", value: "\(Int(windData.speed)) kts")
                if let gust = windData.gust {
                    DetailItem(title: "Gust", value: "\(Int(gust)) kts", isGust: true)
                }
            }
        }
        .padding(.vertical, 20)  // More vertical padding
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
                .shadow(color: .black.opacity(0.3), radius: 10)
        )
        .offset(y: isAppearing ? 0 : 100)  // Slide up animation
        .opacity(isAppearing ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAppearing = true
            }
        }
    }
}

struct DetailItem: View {
    let title: String
    let value: String
    var isGust: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.system(.body, design: .rounded))
                .foregroundColor(isGust ? .red : .white)
        }
    }
}

// Update MapViewModel
@MainActor
class MapViewModel: ObservableObject {
    @Published var windData: [String: WindData] = [:]
    @Published var flights: [FlightRadarService.FlightData] = []
    @Published var error: WeatherError?
    @Published var currentAirportIndex = 0
    
    private let weatherService = WeatherService()
    private let flightService = FlightRadarService()
    private var flightUpdateTimer: Timer?
    private var internationalAirports: [Airport] {
        Airport.dominicanAirports.filter { $0.type == .international }
    }
    
    func startFlightTracking() async {
        // Update more frequently and cycle through airports
        flightUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task {
                await self?.updateFlightsForNextAirport()
            }
        }
        
        // Initial fetch
        await updateFlightsForNextAirport()
    }
    
    private func updateFlightsForNextAirport() async {
        guard !internationalAirports.isEmpty else { return }
        
        let airport = internationalAirports[currentAirportIndex]
        print("🔄 Updating flights for \(airport.name)...")
        
        do {
            let airportFlights = try await flightService.fetchFlights(near: airport)
            print("✈️ Found \(airportFlights.count) flights near \(airport.name)")
            
            // Merge new flights with existing ones, removing duplicates
            let existingFlights = flights.filter { flight in
                // Keep flights that aren't from the current airport's area
                let flightLocation = CLLocation(latitude: flight.latitude, longitude: flight.longitude)
                let airportLocation = CLLocation(latitude: airport.latitude, longitude: airport.longitude)
                return flightLocation.distance(from: airportLocation) > 100000 // 100km
            }
            
            flights = Array(Set(existingFlights + airportFlights))
            print("📊 Total flights tracked: \(flights.count)")
            
            // Move to next airport
            currentAirportIndex = (currentAirportIndex + 1) % internationalAirports.count
            
        } catch {
            print("❌ Error fetching flights for \(airport.name): \(error.localizedDescription)")
            self.error = error as? WeatherError ?? .networkError(error)
            
            // Even if there's an error, move to next airport
            currentAirportIndex = (currentAirportIndex + 1) % internationalAirports.count
        }
    }
    
    func fetchAllWindData() async {
        // Fetch wind data for all airports
        for airport in Airport.dominicanAirports {
            do {
                let data = try await weatherService.fetchWindData(for: airport)
                windData[airport.id] = data
            } catch {
                self.error = error as? WeatherError ?? .networkError(error)
            }
        }
    }
    
    deinit {
        flightUpdateTimer?.invalidate()
    }
}

// Update the AirportMarkerView with better touch targets and animations
struct AirportMarkerView: View {
    let airport: Airport
    let windData: WindData?
    @State private var isPressed = false  // For touch feedback
    
    var body: some View {
        VStack(spacing: 8) {
            if let windData = windData {
                // Wind direction indicator with animation
                Image(systemName: "arrow.up")
                    .rotationEffect(.degrees(windData.direction))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)  // Following Apple's 44pt minimum touch target
                    .background(markerColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 2)
                    .scaleEffect(isPressed ? 0.95 : 1.0)  // Touch feedback
                    .animation(.spring(response: 0.3), value: isPressed)
            }
            
            // Airport marker with improved visibility
            Image(systemName: "airplane.departure")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(markerColor)
                .frame(width: 44, height: 44)  // Following Apple's 44pt minimum touch target
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .shadow(color: .black.opacity(0.1), radius: 4)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .pressEvents(onPress: { pressed in
            withAnimation(.easeInOut(duration: 0.2)) {
                isPressed = pressed
            }
        })
    }
    
    private var markerColor: Color {
        switch airport.type {
        case .international:
            return .blue
        case .domestic:
            return .green
        case .privateField:
            return .orange
        }
    }
}

// Add this extension for press gesture
extension View {
    func pressEvents(onPress: @escaping (Bool) -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress(true) }
                .onEnded { _ in onPress(false) }
        )
    }
}

#Preview {
    MapView()
} 