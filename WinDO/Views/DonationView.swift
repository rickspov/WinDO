import SwiftUI

// MARK: - View Models
class DonationViewModel: ObservableObject {
    @Published var donationStats: DonationStats?
    
    func loadDonationStats() {
        donationStats = DonationStats(
            totalAmount: UserDefaults.standard.double(forKey: "totalDonations"),
            donorCount: UserDefaults.standard.integer(forKey: "donorCount"),
            lastDonor: UserDefaults.standard.string(forKey: "lastDonor")
        )
    }
    
    func trackDonation(amount: Double) {
        let currentTotal = UserDefaults.standard.double(forKey: "totalDonations")
        let currentCount = UserDefaults.standard.integer(forKey: "donorCount")
        
        UserDefaults.standard.set(currentTotal + amount, forKey: "totalDonations")
        UserDefaults.standard.set(currentCount + 1, forKey: "donorCount")
        UserDefaults.standard.set("Anonymous", forKey: "lastDonor")
        
        loadDonationStats()
    }
}

// MARK: - Models
struct DonationStats {
    let totalAmount: Double
    let donorCount: Int
    let lastDonor: String?
}

// MARK: - Main View
struct DonationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DonationViewModel()
    @State private var selectedAmount: Double = 5.0
    @State private var customAmount: String = ""
    @State private var showThankYou = false
    
    private let predefinedAmounts = [1.0, 5.0, 10.0, 20.0]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                            .scaleEffect(1.1)
                            .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                        
                        Text("Support WinDO")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Help us keep the wind blowing!")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Amount Selection
                    VStack(spacing: 20) {
                        Text("Select Amount")
                            .font(.headline)
                        
                        HStack(spacing: 15) {
                            ForEach(predefinedAmounts, id: \.self) { amount in
                                Button(action: { selectedAmount = amount }) {
                                    Text("$\(Int(amount))")
                                        .font(.headline)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedAmount == amount ? Color.blue : Color.gray.opacity(0.2))
                                        )
                                        .foregroundColor(selectedAmount == amount ? .white : .primary)
                                }
                            }
                        }
                        
                        // Custom amount
                        HStack {
                            Text("$")
                            TextField("Custom", text: $customAmount)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                        }
                    }
                    
                    // PayPal Button
                    Button(action: handlePayPal) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                            Text("Donate with PayPal")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.top)
                    
                    // Stats
                    if let stats = viewModel.donationStats {
                        StatItemView(title: "Total Donations", value: "$\(Int(stats.totalAmount))")
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showThankYou) {
            ThankYouView()
        }
        .onAppear {
            viewModel.loadDonationStats()
        }
    }
    
    private func handlePayPal() {
        let amount = customAmount.isEmpty ? String(format: "%.2f", selectedAmount) : customAmount
        if let url = URL(string: "https://paypal.me/rickspov?country.x=US&locale.x=en_US\(amount)USD") {
            UIApplication.shared.open(url)
            viewModel.trackDonation(amount: Double(amount) ?? selectedAmount)
            showThankYou = true
        }
    }
}

// MARK: - Supporting Views
struct StatItemView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

struct ThankYouView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
                .scaleEffect(1.1)
                .animation(.easeInOut(duration: 1).repeatForever(), value: true)
            
            Text("Thank You!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your support helps us maintain and improve WinDO.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Close") {
                dismiss()
            }
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    DonationView()
} 
