import Foundation
import ServiceManagement

if #available(macOS 13.0, *) {
    let service = SMAppService.daemon(plistName: "com.abhinav.glide-daemon.plist")
    do {
        try service.unregister()
        print("Successfully unregistered the daemon.")
    } catch {
        print("Failed to unregister: \(error)")
    }
} else {
    print("Requires macOS 13.0+")
}
