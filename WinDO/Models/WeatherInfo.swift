import SwiftUI

struct WeatherInfo: Codable {
    let temperature: Double
    let condition: WeatherCondition
    let pressure: Double
    let humidity: Int
    let visibility: Double
    let feelsLike: Double
    let cloudCover: Int
    let dewPoint: Double?
    let sunrise: Date?
    let sunset: Date?
    
    // Convert hPa to inHg
    var altimeter: String {
        let inHg = pressure * 0.02953
        return String(format: "%.2f", inHg)
    }
    
    // Convert visibility to nautical miles
    var visibilityNM: Double {
        visibility / 1852 // Convert meters to nautical miles
    }
    
    enum WeatherCondition: String, Codable {
        case clear = "clear"
        case cloudy = "clouds"
        case rain = "rain"
        case storm = "thunderstorm"
        case snow = "snow"
        case mist = "mist"
        case haze = "haze"
        
        var icon: String {
            switch self {
            case .clear: return "sun.max.fill"
            case .cloudy: return "cloud.fill"
            case .rain: return "cloud.rain.fill"
            case .storm: return "cloud.bolt.rain.fill"
            case .snow: return "cloud.snow.fill"
            case .mist, .haze: return "cloud.fog.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .clear: return .yellow
            case .cloudy: return .gray
            case .rain: return .blue
            case .storm: return .purple
            case .snow: return .white
            case .mist, .haze: return .gray.opacity(0.7)
            }
        }
        
        var description: String {
            switch self {
            case .clear: return "Clear Skies"
            case .cloudy: return "Cloudy"
            case .rain: return "Rain"
            case .storm: return "Thunderstorm"
            case .snow: return "Snow"
            case .mist: return "Mist"
            case .haze: return "Haze"
            }
        }
    }
} 