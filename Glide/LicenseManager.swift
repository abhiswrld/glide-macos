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
        if case .licensed = status { return true }
        if case .earlyAdopter = status { return true }
        return false
    }
    
    private let serviceName = "com.glide.license"
    private let accountName = "glide_pro_key"
    private let instanceAccountName = "glide_pro_instance_id"
    
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
            disableProFeatures()
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
            if let instanceId = response.instance?.id {
                saveInstanceToKeychain(instanceId: instanceId)
            }
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
            removeInstanceFromKeychain()
            self.status = .unverified
            disableProFeatures()
            if let errorMsg = response.error {
                self.status = .error(errorMsg)
            }
        }
    }
    
    func deactivateLicense() async {
        if let key = loadKeyFromKeychain(), let instanceId = loadInstanceFromKeychain() {
            let url = URL(string: "https://api.lemonsqueezy.com/v1/licenses/deactivate")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let bodyString = "license_key=\(key)&instance_id=\(instanceId)"
            request.httpBody = bodyString.data(using: .utf8)
            
            _ = try? await URLSession.shared.data(for: request)
        }
        
        removeKeyFromKeychain()
        removeInstanceFromKeychain()
        self.status = .unverified
        
        disableProFeatures()
    }
    
    private func disableProFeatures() {
        // Disable Pro features so they don't run in the background without a license
        UserDefaults.standard.set(false, forKey: "smartChargingEnabled")
        UserDefaults.standard.set(false, forKey: "sailingEnabled")
        UserDefaults.standard.set(false, forKey: "heatProtectionEnabled")
        UserDefaults.standard.set(false, forKey: "forceDischargeEnabled")
        // Don't forcefully switch icon here, users might prefer standard icon anyway.
        // Actually, if we reset it, they might lose custom icon choice.
        // Let's reset to standard to be safe.
        UserDefaults.standard.set("standard", forKey: "menuBarIcon")
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
    
    private func saveInstanceToKeychain(instanceId: String) {
        let data = instanceId.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: instanceAccountName,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func loadInstanceFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: instanceAccountName,
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
    
    private func removeInstanceFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: instanceAccountName
        ]
        SecItemDelete(query as CFDictionary)
    }
}
