//
//  ContentView.swift
//  WinDO
//
//  Created by Ricardo Rodriguez on 4/11/24.
//

import SwiftUI
import MapKit

enum AppLanguage: String {
    case english = "en"
    case spanish = "es"
}

// Add the formatTime function here
private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

struct LanguageSelector: View {
    @AppStorage("appLanguage") private var selectedLanguage = AppLanguage.english
    @State private var showingRestartAlert = false
    @State private var pendingLanguage: AppLanguage?
    
    var body: some View {
        Button(action: {
            pendingLanguage = selectedLanguage == .english ? .spanish : .english
            showingRestartAlert = true
        }) {
            Text(selectedLanguage == .english ? "EN" : "ESP")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .alert(selectedLanguage == .english ? "Change Language" : "Cambiar Idioma", isPresented: $showingRestartAlert) {
            Button(selectedLanguage == .english ? "Cancel" : "Cancelar", role: .cancel) {
                pendingLanguage = nil
            }
            Button(selectedLanguage == .english ? "Restart" : "Reiniciar", role: .destructive) {
                if let newLanguage = pendingLanguage {
                    selectedLanguage = newLanguage
                    UserDefaults.standard.set([newLanguage.rawValue], forKey: "AppleLanguages")
                    exit(0)
                }
            }
        } message: {
            Text(selectedLanguage == .english ? 
                 "The app needs to restart to change the language. Continue?" :
                 "La aplicación necesita reiniciarse para cambiar el idioma. ¿Continuar?")
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab?
    @StateObject private var viewModel = WindViewModel()
    @StateObject private var locationService = LocationService()
    private let colors = AppColors()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient with animation
                LinearGradient(
                    colors: [colors.skyBlueLight, colors.skyBlueDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: selectedTab)
                
                // Add clouds background
                CloudsBackgroundView()
                    .allowsHitTesting(false)  // Ensures clouds don't interfere with interactions
                
                // Content with transitions
                Group {
                    if selectedTab == nil {
                        LandingMenuView(selectedTab: $selectedTab)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 1.0).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                    } else {
                        selectedView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedTab)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.selectedAirport != nil || selectedTab != nil {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if viewModel.selectedAirport != nil {
                                    viewModel.selectedAirport = nil
                                    viewModel.windData = nil
                                } else if selectedTab != nil {
                                    selectedTab = nil
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                            }
                            .foregroundColor(.white)
                        }
                        .transition(.opacity)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text(navigationTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab != nil {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTab = nil
                            }
                        }) {
                            Image(systemName: "house.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .medium))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .gesture(
                DragGesture()
                    .onEnded { gesture in
                        if gesture.translation.width > 100 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if viewModel.selectedAirport != nil {
                                    viewModel.selectedAirport = nil
                                    viewModel.windData = nil
                                } else if selectedTab != nil {
                                    selectedTab = nil
                                }
                            }
                        }
                    }
            )
        }
        .tint(.white)
        .overlay {
            if locationService.showLocationPermissionAlert {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        LocationPermissionAlert(locationService: locationService)
                    }
            }
        }
        .onAppear {
            Task {
                await testWeatherAPI()
            }
        }
    }
    
    private var selectedView: some View {
        Group {
            switch selectedTab {
            case .airports:
                AirportListView()
            case .map:
                MapView()
            case .none:
                EmptyView()
            }
        }
    }
    
    private var navigationTitle: String {
        switch selectedTab {
        case .airports:
            return "Airports"
        case .map:
            return "Map"
        case .none:
            return "WinDO"
        }
    }
    
    private func testWeatherAPI() async {
        print("🧪 Starting Weather API Test...")
        
        // Test with Punta Cana Airport
        let testAirport = Airport.dominicanAirports[0] // MDPC
        
        do {
            let weatherService = WeatherService()
            print("📍 Testing location: \(testAirport.name)")
            
            // Test wind data
            let windData = try await weatherService.fetchWindData(for: testAirport)
            print("✅ Wind Data Test successful!")
            print("Wind Direction: \(windData.direction)°")
            print("Wind Speed: \(windData.speed) knots")
            if let gust = windData.gust {
                print("Gust Speed: \(gust) knots")
            }
            
            // Test weather info
            let weatherInfo = try await weatherService.fetchWeatherInfo(
                latitude: testAirport.latitude,
                longitude: testAirport.longitude
            )
            print("✅ Weather Info Test successful!")
            print("Temperature: \(weatherInfo.temperature)°C")
            print("Condition: \(weatherInfo.condition)")
            print("Altimeter: \(weatherInfo.altimeter) inHg")
            
        } catch {
            print("❌ API Test failed")
            print("Error: \(error)")
            if let weatherError = error as? WeatherError {
                print("Weather Error: \(weatherError.userMessage)")
            }
        }
    }
}

// MARK: - Landing Menu
struct LandingMenuView: View {
    @Binding var selectedTab: AppTab?
    @State private var showDonation = false
    @State private var showFeedback = false
    @StateObject private var weatherViewModel = WeatherViewModel()
    private let colors = AppColors()
    
    var body: some View {
        VStack(spacing: 30) {
            // Language and weather row
            HStack {
                if let weather = weatherViewModel.currentWeather {
                    WeatherWidget(
                        temperature: weather.temperature,
                        condition: weather.condition
                    )
                }
                
                Spacer()
                
                LanguageSelector()
            }
            .padding(.horizontal)
            
            // App logo or icon
            Image(systemName: "wind")
                .font(.system(size: 60))
                .foregroundColor(.white)
                .padding(.bottom, 40)
            
            // Menu options
            VStack(spacing: 20) {
                MenuButton(
                    title: String(localized: "Airport List"),
                    icon: "list.bullet",
                    action: { selectedTab = .airports }
                )
                
                MenuButton(
                    title: String(localized: "Map View"),
                    icon: "map",
                    action: { selectedTab = .map }
                )
            }
            
            Spacer()
            
            // Buttons row
            HStack(spacing: 15) {
                // Donation Button
                Button(action: {
                    showDonation = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .symbolEffect(.pulse)
                        Text("Support the Developer")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.15))
                    )
                }
                
                // Feedback Button
                Button(action: {
                    showFeedback = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                        Text("Feedback")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.15))
                    )
                }
                .sheet(isPresented: $showFeedback) {
                    FeedbackView()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
            .sheet(isPresented: $showDonation) {
                DonationView()
            }
            
            // Add this at the bottom after the donation/feedback buttons
            VStack(spacing: 4) {
                Text("Version 1.1 Beta")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                
                Text("Created by Ricardo Rodriguez")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.bottom, 10)
        }
        .padding()
        .onAppear {
            Task {
                await weatherViewModel.fetchCurrentWeather()
            }
        }
    }
}

// MARK: - Supporting Views
struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .frame(width: 30)
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .opacity(0.7)
                    .scaleEffect(isPressed ? 1.2 : 1.0)
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.15))
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// Add this custom button style
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Supporting Types
enum AppTab {
    case airports
    case map
}

// MARK: - Airport List View
struct AirportListView: View {
    @StateObject private var viewModel = WindViewModel()
    @StateObject private var locationService = LocationService()
    
    var body: some View {
        VStack(spacing: 20) {
            // Search bar (only show when no airport is selected)
            if viewModel.selectedAirport == nil {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("Search airports", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .tint(.white)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.white.opacity(0.15))
                )
                .padding(.horizontal)
            }
            
            if let selectedAirport = viewModel.selectedAirport,
               let windData = viewModel.windData {
                ScrollView {
                    VStack(spacing: 30) {
                        // Airport info header with enhanced weather display
                        VStack(spacing: 12) {
                            Text(selectedAirport.name)
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text(selectedAirport.city)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            // Enhanced Weather Info
                            if let weather = viewModel.currentWeather {
                                VStack(spacing: 15) {
                                    // First row: Temperature, Condition, and Altimeter
                                    HStack(spacing: 20) {
                                        WeatherInfoBox(
                                            icon: weather.condition.icon,
                                            value: String(format: "%.1f°C", weather.temperature),
                                            color: weather.condition.color
                                        )
                                        
                                        WeatherInfoBox(
                                            icon: "gauge.medium",
                                            value: weather.altimeter,
                                            color: .white
                                        )
                                        
                                        WeatherInfoBox(
                                            icon: "thermometer.medium",
                                            value: String(format: "%.1f°C", weather.feelsLike),
                                            subtitle: "Feels like",
                                            color: .orange
                                        )
                                    }
                                    
                                    // Second row: Visibility, Humidity, Cloud Cover
                                    HStack(spacing: 20) {
                                        WeatherInfoBox(
                                            icon: "eye.fill",
                                            value: String(format: "%.1f NM", weather.visibilityNM),
                                            subtitle: "Visibility",
                                            color: .cyan
                                        )
                                        
                                        WeatherInfoBox(
                                            icon: "humidity.fill",
                                            value: "\(weather.humidity)%",
                                            subtitle: "Humidity",
                                            color: .blue
                                        )
                                        
                                        WeatherInfoBox(
                                            icon: "cloud.fill",
                                            value: "\(weather.cloudCover)%",
                                            subtitle: "Clouds",
                                            color: .gray
                                        )
                                    }
                                    
                                    // Third row: Sunrise and Sunset (if available)
                                    if let sunrise = weather.sunrise,
                                       let sunset = weather.sunset {
                                        HStack(spacing: 20) {
                                            WeatherInfoBox(
                                                icon: "sunrise.fill",
                                                value: formatTime(sunrise),
                                                subtitle: "Sunrise",
                                                color: .yellow
                                            )
                                            
                                            WeatherInfoBox(
                                                icon: "sunset.fill",
                                                value: formatTime(sunset),
                                                subtitle: "Sunset",
                                                color: .orange
                                            )
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.top)
                        .padding(.horizontal)
                        
                        // Compass view
                        CompassView(
                            windDirection: windData.direction,
                            windSpeed: windData.speed,
                            gust: windData.gust
                        )
                        .frame(height: UIScreen.main.bounds.height * 0.45)
                        .padding()
                        
                        // Historical and forecast section
                        VStack(spacing: 20) {
                            Text("Wind History & Forecast")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            // Use VStack instead of HStack for vertical layout
                            VStack(spacing: 20) {
                                // Past data
                                WindHistoryView(title: "Past 6 Hours", windData: viewModel.windHistory)
                                    .frame(height: 200)  // Fixed height
                                
                                // Future data
                                WindHistoryView(title: "Next 6 Hours", windData: viewModel.windForecast)
                                    .frame(height: 200)  // Fixed height
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.1))
                        )
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            } else {
                // Airport list
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(viewModel.filteredAirports) { airport in
                            Button(action: {
                                viewModel.selectedAirport = airport
                                Task {
                                    await viewModel.fetchWindData(for: airport)
                                }
                            }) {
                                AirportRowView(airport: airport)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            if viewModel.selectedAirport == nil,
               let nearestAirport = locationService.nearestAirport {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Nearest Airport")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if let currentCity = locationService.currentCity {
                            Text("from \(currentCity)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Button(action: {
                        viewModel.selectedAirport = nearestAirport
                        Task {
                            await viewModel.fetchWindData(for: nearestAirport)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(nearestAirport.name)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                
                                HStack {
                                    Text(nearestAirport.city)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    if let distance = locationService.getFormattedDistance() {
                                        Text("• \(distance)")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                }
                .padding()
            }
        }
        .onAppear {
            locationService.requestPermission()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let airport = viewModel.selectedAirport {
                    Text(airport.city)
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    Text("Airports")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error.userMessage)
            }
        }
    }
}

// MARK: - Supporting Views
struct AirportRowView: View {
    let airport: Airport
    private let colors = AppColors()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(airport.city)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // Airport type indicator
                    Text(airport.type.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(typeColor.opacity(0.3))
                        )
                        .foregroundColor(typeColor)
                }
                
                Text(airport.name)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.7))
                .font(.system(size: 14, weight: .semibold))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.15))
        )
    }
    
    private var typeColor: Color {
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

struct WindHistoryView: View {
    let title: String
    let windData: [WeatherService.WindHistory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 4)
            
            // Scrollable content for multiple entries
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(windData, id: \.time) { data in
                        HStack(spacing: 12) {
                            // Time
                            Text(formatTime(data.time))
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 60, alignment: .leading)
                            
                            // Wind direction with arrow
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up")
                                    .rotationEffect(.degrees(data.direction))
                                    .font(.system(size: 12, weight: .bold))
                                
                                Text("\(Int(data.direction))°")
                            }
                            .foregroundColor(.white)
                            .frame(width: 60)
                            
                            // Wind speed
                            Text("\(Int(data.speed))")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 30, alignment: .trailing)
                            
                            Text("kts")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            
                            // Gust if available
                            if let gust = data.gust {
                                Text("G\(Int(gust))")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.red.opacity(0.9))
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.2))
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        if title.contains("Past") {
            let hours = Calendar.current.dateComponents([.hour], from: date, to: Date()).hour ?? 0
            return "\(abs(hours))h ago"
        } else {
            let hours = Calendar.current.dateComponents([.hour], from: Date(), to: date).hour ?? 0
            return "+\(hours)h"
        }
    }
}

// Small arrow for history/forecast
struct SmallWindArrow: Shape {
    let direction: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Simple line with a small head
        path.move(to: CGPoint(x: width/2, y: height * 0.2)) // Arrow tip
        path.addLine(to: CGPoint(x: width/2, y: height * 0.8)) // Arrow tail
        
        // Arrow head
        path.move(to: CGPoint(x: width/2, y: height * 0.2)) // Tip
        path.addLine(to: CGPoint(x: width/2 - width * 0.2, y: height * 0.35)) // Left wing
        path.move(to: CGPoint(x: width/2, y: height * 0.2)) // Back to tip
        path.addLine(to: CGPoint(x: width/2 + width * 0.2, y: height * 0.35)) // Right wing
        
        return path
    }
}

// MARK: - Colors
struct AppColors {
    let skyBlueLight = Color(red: 0.529, green: 0.808, blue: 0.922) // #87CEEB - Sky Blue
    let skyBlue = Color(red: 0.392, green: 0.584, blue: 0.929)      // #6495ED - Cornflower Blue
    let skyBlueDark = Color(red: 0.275, green: 0.510, blue: 0.706)  // #4682B4 - Steel Blue
    let windRed = Color(red: 0.8, green: 0.2, blue: 0.2)
}

// Add this to LandingMenuView
struct WeatherWidget: View {
    let temperature: Double
    let condition: WeatherInfo.WeatherCondition
    
    var body: some View {
        HStack(spacing: 15) {
            // Weather icon
            Image(systemName: condition.icon)
                .font(.system(size: 24))
                .foregroundColor(condition.color)
                .scaleEffect(1.1)
                .animation(.easeInOut(duration: 1).repeatForever(), value: true)
            
            // Temperature
            Text(String(format: "%.1f°", temperature))
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.1))
        )
    }
}

// Add WeatherViewModel
@MainActor
class WeatherViewModel: ObservableObject {
    @Published var currentWeather: WeatherInfo?
    private let weatherService = WeatherService()
    
    func fetchCurrentWeather() async {
        do {
            // Use Santo Domingo's coordinates as default
            currentWeather = try await weatherService.fetchWeatherInfo(
                latitude: 18.4861,
                longitude: -69.9312
            )
        } catch {
            print("Error fetching weather: \(error)")
        }
    }
}

// Add this new component
struct WeatherInfoBox: View {
    let icon: String
    let value: String
    var subtitle: String? = nil
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.white)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(minWidth: 80)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

// Add this struct after the WeatherInfoBox struct
struct LocationPermissionAlert: View {
    @ObservedObject var locationService: LocationService
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Enable Location Services")
                .font(.headline)
            
            Text("WinDO uses your location to show you the nearest airport and provide accurate weather information.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                locationService.requestPermission()
                locationService.showLocationPermissionAlert = false
            }) {
                Text("Enable Location")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            Button(action: {
                locationService.showLocationPermissionAlert = false
            }) {
                Text("Maybe Later")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
        )
        .shadow(radius: 20)
        .padding()
    }
}

#Preview {
    ContentView()
}

