import SwiftUI

struct SplashScreen: View {
    @State private var isAnimating = false
    @State private var showMainContent = false
    
    var body: some View {
        if showMainContent {
            ContentView()
        } else {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [AppColors().skyBlueLight, AppColors().skyBlueDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // App logo
                    Image(systemName: "wind")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 1 : 0.6)
                    
                    // App name
                    Text("WinDO")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(isAnimating ? 1 : 0)
                    
                    // Beta message
                    VStack(spacing: 15) {
                        Text("Beta Testing")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("This app is currently in beta testing.\nYour feedback is greatly appreciated!")
                            .multilineTextAlignment(.center)
                            .font(.body)
                            .opacity(0.9)
                    }
                    .foregroundColor(.white)
                    .opacity(isAnimating ? 1 : 0)
                    .padding(.top, 20)
                }
                .padding()
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5)) {
                    isAnimating = true
                }
                
                // Transition to main content after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        showMainContent = true
                    }
                }
            }
        }
    }
} 