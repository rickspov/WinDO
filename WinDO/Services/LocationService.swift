import CoreLocation

class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var nearestAirport: Airport?
    @Published var currentCity: String?
    @Published var distanceToNearestAirport: Double?
    @Published var showLocationPermissionAlert = true
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1000 // Update every 1km of movement
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func findNearestAirport() {
        guard let userLocation = currentLocation else { return }
        
        // Find nearest airport and calculate distance
        var closest: (airport: Airport, distance: Double)?
        
        for airport in Airport.dominicanAirports {
            let airportLocation = CLLocation(
                latitude: airport.latitude,
                longitude: airport.longitude
            )
            let distance = userLocation.distance(from: airportLocation)
            
            if closest == nil || distance < closest!.distance {
                closest = (airport, distance)
            }
        }
        
        if let closest = closest {
            self.nearestAirport = closest.airport
            self.distanceToNearestAirport = closest.distance / 1000 // Convert to kilometers
            
            // Get city name from coordinates
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(userLocation) { [weak self] placemarks, error in
                if let city = placemarks?.first?.locality {
                    DispatchQueue.main.async {
                        self?.currentCity = city
                    }
                }
            }
        }
    }
    
    // Get formatted distance string
    func getFormattedDistance() -> String? {
        guard let distance = distanceToNearestAirport else { return nil }
        return String(format: "%.1f km", distance)
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.startUpdatingLocation()
            case .denied, .restricted:
                print("Location access denied")
            case .notDetermined:
                self.requestPermission()
            @unknown default:
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
            self.findNearestAirport()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
