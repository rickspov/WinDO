import SwiftUI
import MessageUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var showMailView = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let emailAddress = "rianroca313@gmail.com"
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Feedback instructions
                    Text("Your feedback helps improve WinDO")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top)
                    
                    // Feedback text editor
                    TextEditor(text: $feedbackText)
                        .frame(height: 200)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .foregroundColor(.white)
                        .tint(.white)
                        .overlay(
                            Group {
                                if feedbackText.isEmpty {
                                    Text("Write your feedback here...")
                                        .foregroundColor(.white.opacity(0.3))
                                        .padding(16)
                                        .allowsHitTesting(false)
                                }
                            }
                        )
                    
                    // Updated Send button
                    Button(action: {
                        if MFMailComposeViewController.canSendMail() {
                            showMailView = true
                        } else {
                            sendFeedbackAlternative()
                        }
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send Feedback")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(feedbackText.isEmpty)
                    
                    // Contact info
                    VStack(spacing: 4) {
                        Text("Or email us directly at:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Button(action: {
                            UIPasteboard.general.string = emailAddress
                            alertMessage = "Email address copied to clipboard"
                            showAlert = true
                        }) {
                            Text(emailAddress)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showMailView) {
                MailView(content: feedbackText) { result in
                    switch result {
                    case .success:
                        alertMessage = "Thank you for your feedback!"
                        showAlert = true
                    case .failure:
                        alertMessage = "Could not send email. Would you like to copy your feedback to clipboard?"
                        showAlert = true
                    }
                }
            }
        }
        .alert("Feedback", isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("Thank you") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func sendFeedbackAlternative() {
        let emailSubject = "WinDO App Feedback"
        let emailBody = feedbackText.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        let mailToUrl = "mailto:\(emailAddress)?subject=\(emailSubject)&body=\(emailBody)"
        
        if let url = URL(string: mailToUrl),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            dismiss()
        } else {
            UIPasteboard.general.string = feedbackText
            alertMessage = "Email app not available. Feedback copied to clipboard."
            showAlert = true
        }
    }
}

// Mail View Controller wrapper
struct MailView: UIViewControllerRepresentable {
    let content: String
    let completion: (Result<Void, Error>) -> Void
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients(["rianroca313@gmail.com"])
        mailComposer.setSubject("WinDO App Feedback")
        mailComposer.setMessageBody(content, isHTML: false)
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let completion: (Result<Void, Error>) -> Void
        
        init(completion: @escaping (Result<Void, Error>) -> Void) {
            self.completion = completion
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, 
                                 didFinishWith result: MFMailComposeResult, 
                                 error: Error?) {
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
            controller.dismiss(animated: true)
        }
    }
} 