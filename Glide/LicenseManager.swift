import Foundation
import SwiftUI
import Security

enum LicenseStatus: Equatable {
    case unverified
    case licensed(key: String)
    case earlyAdopter
    case error(String)
}

struct LemonSqueezyResponse: Codable {
    let valid: Bool?
    let activated: Bool?
    let error: String?
    let license_key: LicenseKeyData?
    let instance: InstanceData?
    
    var isSuccessful: Bool {
        return (valid == true) || (activated == true)
    }
}

struct LicenseKeyData: Codable {
    let status: String
}

struct InstanceData: Codable {
    let id: String
}

@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    
    @Published var status: LicenseStatus = .unverified
    
    var isPro: Bool {
        return true // TEMPORARY DEV OVERRIDE
    }
    
    private let serviceName = "com.glide.license"
    private let accountName = "glide_pro_key"
    
    private init() {
        checkStatus()
    }
    
    /// Verify stored license on launch
    func checkStatus() {
        if let savedKey = loadKeyFromKeychain() {
            // We have a key, let's validate it in the background
            self.status = .licensed(key: savedKey)
            
            Task {
                do {
                    try await validateLicense(key: savedKey)
                } catch {
                    // Silently fail if offline, trust the keychain for now
                    print("Validation failed: \(error)")
                }
            }
        } else {
            // No key, default to early adopter or unverified
            // In a real release, new users are unverified.
            self.status = .unverified
        }
    }
    
    /// Activate a new license key from the UI
    func activateLicense(key: String) async throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let url = URL(string: "https://api.lemonsqueezy.com/v1/licenses/activate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let instanceName = Host.current().localizedName ?? "Mac"
        let bodyString = "license_key=\(trimmedKey)&instance_name=\(instanceName)"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(LemonSqueezyResponse.self, from: data)
        
        if response.isSuccessful {
            saveKeyToKeychain(key: trimmedKey)
            self.status = .licensed(key: trimmedKey)
        } else {
            let errorMsg = response.error ?? "Invalid license key."
            self.status = .error(errorMsg)
            throw NSError(domain: "LicenseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
    }
    
    /// Validate an existing key
    func validateLicense(key: String) async throws {
        let url = URL(string: "https://api.lemonsqueezy.com/v1/licenses/validate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let bodyString = "license_key=\(key)"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(LemonSqueezyResponse.self, from: data)
        
        if response.isSuccessful == false {
            // Key was revoked or expired
            removeKeyFromKeychain()
            self.status = .unverified
            if let errorMsg = response.error {
                self.status = .error(errorMsg)
            }
        }
    }
    
    func deactivateLicense() {
        removeKeyFromKeychain()
        status = .unverified
    }
    
    // MARK: - Keychain
    
    private func saveKeyToKeychain(key: String) {
        let data = key.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func loadKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    private func removeKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        SecItemDelete(query as CFDictionary)
    }
}
