import Foundation

/// Code shared between the Glide app and the glide-daemon.
/// (The XPC protocol, battery models, and SMC codec land here in later steps.)
public enum GlideCore {
    public static var version: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}
