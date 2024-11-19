import Foundation

struct WindData: Codable {
    let direction: Double // in degrees
    let speed: Double // in knots
    let gust: Double? // optional gust speed
    let timestamp: Date
    
    var speedInNauticalMiles: Double {
        // Knots are already in nautical miles per hour
        speed
    }
    
    // Add coding keys and custom coding if needed
    enum CodingKeys: String, CodingKey {
        case direction
        case speed
        case gust
        case timestamp
    }
    
    // Custom initializer if needed
    init(direction: Double, speed: Double, gust: Double?, timestamp: Date) {
        self.direction = direction
        self.speed = speed
        self.gust = gust
        self.timestamp = timestamp
    }
} 