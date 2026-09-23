import Foundation

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

let json = """
{"activated":true,"error":null,"license_key":{"id":1625081,"status":"active","key":"04AFF854-226A-4ACF-825E-2480027FCD42","activation_limit":3,"activation_usage":1,"created_at":"2026-09-22T05:45:59.000000Z","expires_at":null,"test_mode":false},"instance":{"id":"4647fdf1-ec76-41e0-9d9d-2de33aec15ae","name":"TestMac","created_at":"2026-09-22T05:47:44.000000Z"},"meta":{"store_id":477598,"order_id":9538492,"order_item_id":9462773,"variant_id":2153799,"variant_name":"Default","product_id":1378706,"product_name":"Glide Pro","customer_id":9962489,"customer_name":"Glide","customer_email":"khanna.abhinav06@gmail.com"}}
"""

let data = json.data(using: .utf8)!
do {
    let response = try JSONDecoder().decode(LemonSqueezyResponse.self, from: data)
    print("Success: \(response)")
} catch {
    print("Error: \(error)")
}
