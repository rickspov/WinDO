import Combine
import CoreLocation

@MainActor
class WindViewModel: ObservableObject {
    @Published var selectedAirport: Airport?
    @Published var windData: WindData?
    @Published var searchText = ""
    @Published var filteredAirports: [Airport] = []
    @Published var isLoading = false
    @Published var error: WeatherError?
    @Published var lastUpdateTime: Date?
    @Published var currentWeather: WeatherInfo?
    @Published var windHistory: [WeatherService.WindHistory] = []
    @Published var windForecast: [WeatherService.WindHistory] = []
    @Published var sortedAirports: [Airport] = []
    
    private let weatherService = WeatherService()
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private let locationService = LocationService()
    
    init() {
        setupSearch()
        setupAutoRefresh()
        setupLocationBasedSorting()
    }
    
    private func setupLocationBasedSorting() {
        // Sort airports when location updates
        locationService.$currentLocation
            .sink { [weak self] location in
                guard let location = location else { return }
                self?.sortAirportsByDistance(from: location)
            }
            .store(in: &cancellables)
    }
    
    private func sortAirportsByDistance(from location: CLLocation) {
        let sortedAirports = Airport.dominicanAirports.map { airport -> (Airport, Double) in
            let airportLocation = CLLocation(
                latitude: airport.latitude,
                longitude: airport.longitude
            )
            let distance = location.distance(from: airportLocation)
            return (airport, distance)
        }
        .sorted { $0.1 < $1.1 }
        .map { $0.0 }
        
        // Update filteredAirports based on both search and distance
        if searchText.isEmpty {
            filteredAirports = sortedAirports
        } else {
            filteredAirports = sortedAirports.filter { airport in
                airport.city.localizedCaseInsensitiveContains(searchText) ||
                airport.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func setupSearch() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] searchText in
                guard let self = self else { return }
                if let location = self.locationService.currentLocation {
                    // Re-sort with new search text
                    self.sortAirportsByDistance(from: location)
                } else {
                    // Fallback to regular filtering if location is not available
                    self.filteredAirports = searchText.isEmpty ? Airport.dominicanAirports :
                        Airport.dominicanAirports.filter { airport in
                            airport.city.localizedCaseInsensitiveContains(searchText) ||
                            airport.name.localizedCaseInsensitiveContains(searchText)
                        }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self,
                      let airport = self.selectedAirport else { return }
                await self.fetchWindData(for: airport)
            }
        }
    }
    
    func fetchWindData(for airport: Airport) async {
        isLoading = true
        self.error = nil
        
        do {
            windData = try await weatherService.fetchWindData(for: airport)
            currentWeather = try await weatherService.fetchWeatherInfo(
                latitude: airport.latitude,
                longitude: airport.longitude
            )
            
            let (history, forecast) = try await weatherService.fetchWindHistoryAndForecast(for: airport)
            windHistory = history
            windForecast = forecast
            
            lastUpdateTime = Date()
        } catch let weatherError as WeatherError {
            self.error = weatherError
        } catch {
            self.error = WeatherError.networkError(error)
        }
        
        isLoading = false
    }
    
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
    
    func refreshData() async {
        guard let airport = selectedAirport else { return }
        await fetchWindData(for: airport)
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
} 