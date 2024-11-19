import SwiftUI
import CoreGraphics

struct CompassView: View {
    let windDirection: Double
    let windSpeed: Double
    let gust: Double?
    
    // Animation states
    @State private var isRotating = false
    @State private var isGustAnimating = false
    @State private var showGustIndicator = false
    
    // Colors
    private let colors = AppColors()
    
    var body: some View {
        VStack(spacing: 40) {
            // Wind info above compass with animations
            WindInfo(speed: windSpeed, gust: gust, heading: windDirection)
                .padding(.top, 30)
                .transition(.scale.combined(with: .opacity))
            
            // Compass
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                
                ZStack {
                    // Background effect for weather conditions
                    WeatherEffectView(size: size)
                    
                    // Main compass circle with gradient
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .shadow(color: .white.opacity(0.2), radius: 5)
                    
                    // Inner circle with animation
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .frame(width: size * 0.8, height: size * 0.8)
                        .scaleEffect(isRotating ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isRotating)
                    
                    // Degree marks with fade effect
                    CompassMarks()
                        .frame(width: size * 0.95, height: size * 0.95)
                        .opacity(isRotating ? 0.8 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isRotating)
                    
                    // Cardinal directions
                    CompassDirections()
                        .frame(width: size * 0.95, height: size * 0.95)
                    
                    // Wind arrow with dynamic effects
                    WindArrow()
                        .stroke(
                            LinearGradient(
                                colors: [colors.windRed, colors.windRed.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 3
                        )
                        .rotationEffect(.degrees(windDirection))
                        .frame(width: size * 0.8, height: size * 0.8)
                        .shadow(color: colors.windRed.opacity(0.3), radius: 5)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: windDirection)
                    
                    // Gust indicator
                    if let gust = gust, showGustIndicator {
                        GustIndicator(gust: gust)
                            .opacity(isGustAnimating ? 0.7 : 0)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isGustAnimating)
                    }
                }
                .frame(width: size, height: size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    withAnimation {
                        isRotating = true
                        isGustAnimating = true
                        showGustIndicator = true
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 20)
        }
    }
}

// Weather effect background
struct WeatherEffectView: View {
    let size: CGFloat
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            RadialGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.blue.opacity(0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: size * 0.2,
                endRadius: size * 0.5
            )
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .animation(
                .easeInOut(duration: 2)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
        }
    }
}

// Enhanced gust indicator
struct GustIndicator: View {
    let gust: Double
    
    var body: some View {
        Circle()
            .stroke(Color.red.opacity(0.3), lineWidth: 2)
            .frame(width: 100, height: 100)
            .overlay(
                Text("\(Int(gust)) kts")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.red.opacity(0.7))
            )
    }
}

// MARK: - Subviews
private struct CompassMarks: View {
    var body: some View {
        ZStack {
            // Major marks (every 30 degrees)
            ForEach(0..<12) { i in
                Rectangle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 1.5, height: 15)
                    .offset(y: -130)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            
            // Minor marks (every 10 degrees)
            ForEach(0..<36) { i in
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 1, height: 8)
                    .offset(y: -130)
                    .rotationEffect(.degrees(Double(i) * 10))
            }
        }
    }
}

private struct CompassDirections: View {
    let directions = ["N", "E", "S", "W"]
    
    var body: some View {
        ZStack {
            ForEach(0..<4) { i in
                Text(directions[i])
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .offset(y: -100)
                    .rotationEffect(.degrees(Double(i) * 90))
            }
        }
    }
}

private struct WindArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Simple line with a small head
        path.move(to: CGPoint(x: width/2, y: height * 0.1)) // Arrow tip
        path.addLine(to: CGPoint(x: width/2, y: height * 0.9)) // Arrow tail
        
        // Arrow head
        path.move(to: CGPoint(x: width/2, y: height * 0.1)) // Tip
        path.addLine(to: CGPoint(x: width/2 - 10, y: height * 0.2)) // Left wing
        path.move(to: CGPoint(x: width/2, y: height * 0.1)) // Back to tip
        path.addLine(to: CGPoint(x: width/2 + 10, y: height * 0.2)) // Right wing
        
        return path
    }
}

private struct WindInfo: View {
    let speed: Double
    let gust: Double?
    let heading: Double
    
    var body: some View {
        HStack(spacing: 30) {
            // Wind speed
            InfoBox(
                value: "\(Int(speed))",
                title: "WIND SPEED",
                unit: "KTS"
            )
            
            // Wind heading
            InfoBox(
                value: "\(Int(heading))°",
                title: "HEADING",
                unit: ""
            )
            
            // Gust info (if available)
            if let gust = gust {
                InfoBox(
                    value: "\(Int(gust))",
                    title: "GUST",
                    unit: "KTS",
                    isGust: true
                )
            }
        }
    }
}

private struct InfoBox: View {
    let value: String
    let title: String
    let unit: String
    var isGust: Bool = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(value)
                .font(.system(size: 32, weight: .light))
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .kerning(1)
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .kerning(1)
            }
        }
        .foregroundColor(isGust ? Color.red.opacity(0.9) : .white)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - Preview
struct CompassView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(red: 0.2, green: 0.3, blue: 0.4)
                .ignoresSafeArea()
            
            CompassView(
                windDirection: 45,
                windSpeed: 15,
                gust: 25
            )
            .frame(width: 300, height: 400)
        }
        .previewLayout(.sizeThatFits)
    }
} 