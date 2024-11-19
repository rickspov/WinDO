struct Airport: Identifiable, Codable, Hashable {
    let id: String // ICAO code
    let name: String
    let city: String
    let latitude: Double
    let longitude: Double
    let type: AirportType
    
    // Add hash function for Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)  // Using id since it's unique
    }
    
    // Add equality check for Hashable conformance
    static func == (lhs: Airport, rhs: Airport) -> Bool {
        lhs.id == rhs.id
    }
    
    enum AirportType: String, Codable {
        case international = "International"
        case domestic = "Domestic"
        case privateField = "Private"
    }
    
    // Dominican Republic's airports
    static let dominicanAirports = [
        // International Airports
        Airport(id: "MDPC", name: "Punta Cana International Airport", city: "Punta Cana", 
               latitude: 18.5674, longitude: -68.3634, type: .international),
        Airport(id: "MDSD", name: "Las Américas International Airport", city: "Santo Domingo", 
               latitude: 18.4297, longitude: -69.6689, type: .international),
        Airport(id: "MDST", name: "Cibao International Airport", city: "Santiago", 
               latitude: 19.4069, longitude: -70.6044, type: .international),
        Airport(id: "MDPP", name: "Gregorio Luperón International Airport", city: "Puerto Plata", 
               latitude: 19.7579, longitude: -70.5699, type: .international),
        Airport(id: "MDLR", name: "La Romana International Airport", city: "La Romana", 
               latitude: 18.4507, longitude: -68.9118, type: .international),
        Airport(id: "MDJB", name: "La Isabela International Airport", city: "Santo Domingo North", 
               latitude: 18.5725, longitude: -69.9856, type: .international),
        Airport(id: "MDCY", name: "Samaná El Catey International Airport", city: "Samaná", 
               latitude: 19.2670, longitude: -69.7420, type: .international),
        
        // Domestic Airports
        Airport(id: "MDAB", name: "Arroyo Barril Airport", city: "Samaná", 
               latitude: 19.1989, longitude: -69.4299, type: .domestic),
        Airport(id: "MDBE", name: "Cabo Rojo Airport", city: "Pedernales", 
               latitude: 17.9289, longitude: -71.6446, type: .domestic),
        Airport(id: "MDCR", name: "Constanza Airport", city: "Constanza", 
               latitude: 18.9075, longitude: -70.7219, type: .domestic)
    ]
} 