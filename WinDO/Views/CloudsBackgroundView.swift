import SwiftUI

struct CloudsBackgroundView: View {
    @State private var moveCloud1 = false
    @State private var moveCloud2 = false
    @State private var moveCloud3 = false
    
    var body: some View {
        ZStack {
            // Multiple cloud layers moving at different speeds
            Group {
                // Large slow cloud
                Image(systemName: "cloud.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.white.opacity(0.2))
                    .offset(x: moveCloud1 ? 400 : -400, y: 100)
                    .animation(.linear(duration: 30).repeatForever(autoreverses: false), value: moveCloud1)
                
                // Medium cloud
                Image(systemName: "cloud.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.white.opacity(0.15))
                    .offset(x: moveCloud2 ? 400 : -400, y: -50)
                    .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: moveCloud2)
                
                // Small fast cloud
                Image(systemName: "cloud.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.1))
                    .offset(x: moveCloud3 ? 400 : -400, y: -150)
                    .animation(.linear(duration: 15).repeatForever(autoreverses: false), value: moveCloud3)
            }
        }
        .onAppear {
            moveCloud1 = true
            moveCloud2 = true
            moveCloud3 = true
        }
    }
} 