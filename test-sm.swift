import Foundation
import ServiceManagement

if #available(macOS 13.0, *) {
    let service = SMAppService.daemon(plistName: "com.example.daemon.plist")
    print(service.status.rawValue)
}
