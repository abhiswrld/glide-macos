import Foundation
import GlideCore

let args = Array(CommandLine.arguments.dropFirst())

switch args.first {
case "set":
    guard geteuid() == 0 else { print("run with sudo"); exit(1) }
    guard let value = Int(args.count > 1 ? args[1] : "") else {
        print("usage: sudo glide-daemon set <60-100, step 5>")
        exit(1)
    }
    do {
        try ChargeLimiter.setLimit(value)
        print("limit set to \(value)% — doorbell rung")
    } catch {
        print("failed: \(error)")
        exit(1)
    }
case "limit":
    if let limit = ChargeLimiter.readLimit() {
        print("current limit: \(limit)%")
    } else {
        print("no limit readable (run with sudo)")
    }
default:
    print("""
    glide-daemon \(GlideCore.version)
    usage:
      sudo glide-daemon set <60-100, step 5>   set charge limit
      sudo glide-daemon limit                  read current limit
    """)
}
