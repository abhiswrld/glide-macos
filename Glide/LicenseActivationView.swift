import SwiftUI

struct LicenseActivationView: View {
    @StateObject private var licenseManager = LicenseManager.shared
    
    @State private var licenseKey: String = ""
    @State private var isActivating: Bool = false
    @State private var errorMessage: String?
    
    var onDismiss: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(colors: [GlideTheme.pink, GlideTheme.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: GlideTheme.pink.opacity(0.3), radius: 10, x: 0, y: 5)
                    .padding(.bottom, 4)
                
                Text("Activate Glide Pro")
                    .font(.title3.weight(.heavy))
                
                Text("Enter your Lemon Squeezy license key.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(12)
                    .background(Color.black.opacity(0.2))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .cornerRadius(8)
                    .disabled(isActivating)
                
                if let error = errorMessage {
                    let displayError = error.contains("license_key not found") ? "Invalid key." : error
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(displayError)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GlideTheme.signalRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(GlideTheme.signalRed.opacity(0.15))
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isActivating)
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
                
                Button(action: activate) {
                    if isActivating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Activate Pro")
                            .font(.callout.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(GlideTheme.pink)
                .foregroundStyle(.white)
                .cornerRadius(6)
                .keyboardShortcut(.defaultAction)
                .disabled(licenseKey.trimmingCharacters(in: .whitespaces).isEmpty || isActivating)
            }
        }
        .padding(20)
        .glassCard()
        .padding(16)
        .onChange(of: licenseManager.status) { newStatus in
            if case .licensed = newStatus {
                onDismiss()
            }
        }
    }
    
    private func activate() {
        errorMessage = nil
        isActivating = true
        
        Task {
            do {
                try await licenseManager.activateLicense(key: licenseKey)
                // Success — dismiss directly
                isActivating = false
                onDismiss()
            } catch {
                errorMessage = error.localizedDescription
                isActivating = false
            }
        }
    }
}
