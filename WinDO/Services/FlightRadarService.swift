import Foundation
import CoreLocation

actor FlightRadarService {
    private let baseURL = "https://data-live.flightradar24.com/zones/fcgi/feed.js"
    private let cache = NSCache<NSString, CachedFlightData>()
    private let cacheTimeout: TimeInterval = 10
    
    private let headers = [
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Accept": "application/json",
        "Origin": "https://www.flightradar24.com",
        "Referer": "https://www.flightradar24.com/",
        "Accept-Language": "en-US,en;q=0.9",
        "Connection": "keep-alive"
    ]
    
    final class CachedFlightData {
        let flights: [FlightData]
        let timestamp: Date
        
        init(flights: [FlightData], timestamp: Date) {
            self.flights = flights
            self.timestamp = timestamp
        }
        
        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < 10 // 10 seconds
        }
    }
    
    struct FlightData: Codable, Identifiable, Hashable {
        let id: String
        let callsign: String
        let latitude: Double
        let longitude: Double
        let heading: Double
        let altitude: Int
        let speed: Int
        let aircraft: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: FlightData, rhs: FlightData) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    func fetchFlights(near airport: Airport, radius: Double = 150) async throws -> [FlightData] {
        print("🔍 Starting flight search near \(airport.name)")
        
        let bbox = calculateBoundingBox(
            latitude: airport.latitude,
            longitude: airport.longitude,
            radiusKm: radius
        )
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "bounds", value: "\(bbox.lat1),\(bbox.lat2),\(bbox.lon1),\(bbox.lon2)"),
            URLQueryItem(name: "faa", value: "1"),
            URLQueryItem(name: "satellite", value: "1"),
            URLQueryItem(name: "mlat", value: "1"),
            URLQueryItem(name: "flarm", value: "1"),
            URLQueryItem(name: "adsb", value: "1"),
            URLQueryItem(name: "gnd", value: "1"),
            URLQueryItem(name: "air", value: "1"),
            URLQueryItem(name: "vehicles", value: "1"),
            URLQueryItem(name: "estimated", value: "1"),
            URLQueryItem(name: "maxage", value: "14400"),
            URLQueryItem(name: "gliders", value: "1"),
            URLQueryItem(name: "stats", value: "1"),
            URLQueryItem(name: "enc", value: "L3V~gsf"),
            URLQueryItem(name: "callback", value: "L3V~gsf")
        ]
        
        guard let url = components?.url else {
            print("❌ Invalid URL created")
            throw WeatherError.invalidURL
        }
        
        print("🌐 Requesting URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw WeatherError.invalidResponse
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            print("📦 Raw response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            
            if httpResponse.statusCode != 200 {
                print("❌ Error response")
                throw WeatherError.apiError("Server returned \(httpResponse.statusCode)")
            }
            
            let flights = try parseFlightData(data)
            print("✈️ Found \(flights.count) flights near \(airport.name)")
            
            return flights
            
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func parseFlightData(_ data: Data) throws -> [FlightData] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WeatherError.decodingError
        }
        
        var flights: [FlightData] = []
        
        for (key, value) in json {
            guard 
                key != "full_count" && 
                key != "version" && 
                key != "stats",
                let flightArray = value as? [Any]
            else { continue }
            
            if flightArray.count >= 8,
               let latitude = flightArray[1] as? Double,
               let longitude = flightArray[2] as? Double,
               let heading = flightArray[3] as? Double,
               let altitude = flightArray[4] as? Int,
               let speed = flightArray[5] as? Int,
               let callsign = flightArray[7] as? String {
                
                let flight = FlightData(
                    id: key,
                    callsign: callsign,
                    latitude: latitude,
                    longitude: longitude,
                    heading: heading,
                    altitude: altitude,
                    speed: speed,
                    aircraft: flightArray[8] as? String ?? "Unknown"
                )
                
                flights.append(flight)
                print("🛩 Found flight: \(callsign) at \(latitude),\(longitude)")
            }
        }
        
        return flights
    }
    
    private func calculateBoundingBox(
        latitude: Double,
        longitude: Double,
        radiusKm: Double
    ) -> (lat1: Double, lat2: Double, lon1: Double, lon2: Double) {
        let latDelta = radiusKm / 111.0
        let lonDelta = radiusKm / (111.0 * cos(latitude * .pi / 180.0))
        
        return (
            lat1: latitude - latDelta,
            lat2: latitude + latDelta,
            lon1: longitude - lonDelta,
            lon2: longitude + lonDelta
        )
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
} 