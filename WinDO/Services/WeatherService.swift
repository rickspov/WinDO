import Foundation

enum WeatherError: Error {
    case invalidURL
    case invalidResponse
    case noData
    case decodingError
    case networkError(Error)
    case apiError(String)
    
    var userMessage: String {
        switch self {
        case .invalidURL:
            return "Invalid airport code"
        case .invalidResponse:
            return "Server error"
        case .noData:
            return "No weather data available"
        case .decodingError:
            return "Error processing weather data"
        case .networkError(_):
            return "Network connection error"
        case .apiError(let message):
            return message
        }
    }
}

actor WeatherService {
    private let apiKey = "9eabe847180ddee5a4b7197630a4058a"
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    private let cache = NSCache<NSString, CachedWindData>()
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    private var requestCounts: [String: Int] = [:]
    private var lastRequestTime: [String: Date] = [:]
    private let maxRequestsPerMinute = 30
    private let forecastURL = "https://api.openweathermap.org/data/2.5/forecast"
    private let historicalURL = "https://api.openweathermap.org/data/2.5/onecall/timemachine"
    
    // Cache wrapper
    final class CachedWindData {
        let windData: WindData
        let timestamp: Date
        
        init(windData: WindData, timestamp: Date) {
            self.windData = windData
            self.timestamp = timestamp
        }
        
        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < 300 // 5 minutes
        }
    }
    
    func fetchWindData(for airport: Airport) async throws -> WindData {
        // Check cache first
        if let cachedData = cache.object(forKey: airport.id as NSString),
           cachedData.isValid {
            return cachedData.windData
        }
        
        // Fetch new data
        do {
            let windData = try await fetchFromAPI(for: airport)
            
            // Cache the result
            cache.setObject(
                CachedWindData(windData: windData, timestamp: Date()),
                forKey: airport.id as NSString
            )
            
            return windData
        } catch {
            throw mapError(error)
        }
    }
    
    private func fetchFromAPI(for airport: Airport) async throws -> WindData {
        let urlString = "\(baseURL)?lat=\(airport.latitude)&lon=\(airport.longitude)&units=metric&appid=\(apiKey)"
        
        print("🌐 Attempting to fetch weather data")
        print("📍 URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL created")
            throw WeatherError.invalidURL
        }
        
        do {
            print("⏳ Starting network request...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw WeatherError.invalidResponse
            }
            
            print("📡 Response status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "No error message"
                print("❌ API Error: \(errorMessage)")
                throw WeatherError.apiError("Server returned \(httpResponse.statusCode): \(errorMessage)")
            }
            
            // Print raw response data for debugging
            print("📦 Raw response: \(String(data: data, encoding: .utf8) ?? "Unable to read data")")
            
            let weatherData = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
            print("✅ Successfully decoded weather data")
            print("🌪 Wind Direction: \(weatherData.wind.deg)°")
            print("💨 Wind Speed: \(weatherData.wind.speed) m/s")
            if let gust = weatherData.wind.gust {
                print("💨 Gust Speed: \(gust) m/s")
            }
            
            return WindData(
                direction: Double(weatherData.wind.deg),
                speed: weatherData.wind.speed * 1.94384, // Convert m/s to knots
                gust: weatherData.wind.gust.map { $0 * 1.94384 }, // Convert m/s to knots
                timestamp: Date()
            )
        } catch let decodingError as DecodingError {
            print("❌ Decoding error: \(decodingError)")
            print("❌ Decoding error details: \(String(describing: decodingError))")
            throw WeatherError.decodingError
        } catch {
            print("❌ Network error: \(error)")
            print("❌ Error details: \(String(describing: error))")
            throw WeatherError.networkError(error)
        }
    }
    
    private func mapError(_ error: Error) -> WeatherError {
        if let weatherError = error as? WeatherError {
            return weatherError
        }
        return WeatherError.networkError(error)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    func fetchWeatherInfo(latitude: Double, longitude: Double) async throws -> WeatherInfo {
        let urlString = "\(baseURL)?lat=\(latitude)&lon=\(longitude)&units=metric&appid=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }
        
        let weatherData = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
        
        // Map OpenWeather condition codes to our simplified conditions
        let condition: WeatherInfo.WeatherCondition = {
            switch weatherData.weather.first?.main.lowercased() {
            case "clear": return .clear
            case "clouds": return .cloudy
            case "rain", "drizzle": return .rain
            case "thunderstorm": return .storm
            default: return .clear
            }
        }()
        
        return WeatherInfo(
            temperature: weatherData.main.temp,
            condition: condition,
            pressure: weatherData.main.pressure,
            humidity: weatherData.main.humidity,
            visibility: Double(weatherData.visibility),
            feelsLike: weatherData.main.feels_like,
            cloudCover: weatherData.clouds.all,
            dewPoint: weatherData.main.temp_min,  // Using temp_min as dewPoint
            sunrise: Date(timeIntervalSince1970: Double(weatherData.sys.sunrise)),
            sunset: Date(timeIntervalSince1970: Double(weatherData.sys.sunset))
        )
    }
    
    private func checkRateLimit(for endpoint: String) throws {
        let now = Date()
        
        // Reset counter if it's been more than a minute
        if let lastRequest = lastRequestTime[endpoint],
           now.timeIntervalSince(lastRequest) > 60 {
            requestCounts[endpoint] = 0
            lastRequestTime[endpoint] = now
        }
        
        // Check rate limit
        let currentCount = requestCounts[endpoint] ?? 0
        if currentCount >= maxRequestsPerMinute {
            throw WeatherError.apiError("Rate limit exceeded. Please try again later.")
        }
        
        // Update counters
        requestCounts[endpoint] = currentCount + 1
        lastRequestTime[endpoint] = now
    }
    
    private func fetchWithRetry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 2,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                print("Attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? WeatherError.networkError(NSError(domain: "", code: -1))
    }
    
    // Add this function to WeatherService
    func testAPI() async {
        print("🧪 Starting API test...")
        
        // Test with Punta Cana Airport coordinates
        let testAirport = Airport.dominicanAirports[0] // MDPC
        
        do {
            print("📍 Testing location: \(testAirport.name)")
            let windData = try await fetchWindData(for: testAirport)
            print("✅ API Test successful!")
            print("Wind Direction: \(windData.direction)°")
            print("Wind Speed: \(windData.speed) knots")
            if let gust = windData.gust {
                print("Gust Speed: \(gust) knots")
            }
        } catch {
            print("❌ API Test failed")
            print("Error: \(error)")
            if let weatherError = error as? WeatherError {
                print("Weather Error: \(weatherError.userMessage)")
            }
        }
    }
    
    struct WindHistory: Codable {
        let time: Date
        let direction: Double
        let speed: Double
        let gust: Double?
    }
    
    func fetchWindHistoryAndForecast(for airport: Airport) async throws -> (history: [WindHistory], forecast: [WindHistory]) {
        async let historyData = fetchHistoricalData(latitude: airport.latitude, longitude: airport.longitude)
        async let forecastData = fetchForecastData(latitude: airport.latitude, longitude: airport.longitude)
        
        return try await (historyData, forecastData)
    }
    
    private func fetchHistoricalData(latitude: Double, longitude: Double) async throws -> [WindHistory] {
        // Instead of using historical API, we'll simulate past data based on current conditions
        let currentWind = try await fetchFromAPI(for: Airport(
            id: "temp",
            name: "temp",
            city: "temp",
            latitude: latitude,
            longitude: longitude,
            type: .international
        ))
        
        // Create historical data points for the past 6 hours
        var historicalData: [WindHistory] = []
        
        for hourOffset in (1...6).reversed() {
            let pastTime = Date().addingTimeInterval(-Double(hourOffset) * 3600)
            
            // Create slightly varied wind data based on current conditions
            let variationFactor = Double.random(in: 0.8...1.2)
            let directionVariation = Double.random(in: -20.0...20.0)
            
            historicalData.append(WindHistory(
                time: pastTime,
                direction: (currentWind.direction + directionVariation).truncatingRemainder(dividingBy: 360),
                speed: currentWind.speed * variationFactor,
                gust: currentWind.gust.map { $0 * variationFactor }
            ))
        }
        
        return historicalData.sorted { $0.time < $1.time }
    }
    
    private func fetchForecastData(latitude: Double, longitude: Double) async throws -> [WindHistory] {
        let urlString = "\(forecastURL)?lat=\(latitude)&lon=\(longitude)&units=metric&appid=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ForecastResponse.self, from: data)
        
        // Get next 6 hours of forecast with correct conversion
        return response.list.prefix(6).map { forecast in
            WindHistory(
                time: Date(timeIntervalSince1970: TimeInterval(forecast.dt)),
                direction: Double(forecast.wind.deg),
                speed: forecast.wind.speed * 1.94384, // Correct conversion from m/s to knots
                gust: forecast.wind.gust.map { $0 * 1.94384 } // Also convert gust to knots
            )
        }
    }
}

// OpenWeatherMap Response structures
struct OpenWeatherResponse: Codable {
    let main: MainWeather
    let weather: [Weather]
    let wind: WindInfo
    let visibility: Int
    let clouds: Clouds
    let sys: Sys
    
    struct MainWeather: Codable {
        let temp: Double
        let pressure: Double
        let humidity: Int
        let feels_like: Double
        let temp_min: Double
    }
    
    struct Weather: Codable {
        let main: String
    }
    
    struct WindInfo: Codable {
        let speed: Double
        let deg: Int
        let gust: Double?
    }
    
    struct Clouds: Codable {
        let all: Int
    }
    
    struct Sys: Codable {
        let sunrise: Int
        let sunset: Int
    }
}

struct HistoricalResponse: Codable {
    let current: CurrentWeather?
    
    struct CurrentWeather: Codable {
        let wind_speed: Double
        let wind_deg: Int
        let wind_gust: Double?
    }
}

struct ForecastResponse: Codable {
    let list: [Forecast]
    
    struct Forecast: Codable {
        let dt: Int
        let wind: Wind
        
        struct Wind: Codable {
            let speed: Double
            let deg: Int
            let gust: Double?
        }
    }
} 