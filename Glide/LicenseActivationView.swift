import SwiftUI

struct LicenseActivationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var licenseManager = LicenseManager.shared
    
    @State private var licenseKey: String = ""
    @State private var isActivating: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(GlideTheme.pink)
                    .padding(.bottom, 8)
                
                Text("Activate Glide Pro")
                    .font(.title2.bold())
                
                Text("Enter your Lemon Squeezy license key to unlock all premium features.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 10)
            
            VStack(alignment: .leading, spacing: 8) {
                SecureField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .disabled(isActivating)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isActivating)
                
                Button(action: activate) {
                    if isActivating {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Activate")
                            .frame(minWidth: 60)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(GlideTheme.pink)
                .keyboardShortcut(.defaultAction)
                .disabled(licenseKey.trimmingCharacters(in: .whitespaces).isEmpty || isActivating)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onChange(of: licenseManager.status) { newStatus in
            if case .licensed = newStatus {
                dismiss()
            }
        }
    }
    
    private func activate() {
        errorMessage = nil
        isActivating = true
        
        Task {
            do {
                try await licenseManager.activateLicense(key: licenseKey)
                // Dismiss happens via onChange hook on success
            } catch {
                errorMessage = error.localizedDescription
                isActivating = false
            }
        }
    }
}
