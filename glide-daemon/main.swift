import Foundation
import GlideCore

let args = Array(CommandLine.arguments.dropFirst())

// ---- XPC service mode (default when run by launchd) ----
final class Daemon: NSObject, GlideDaemonProtocol {

    func setLimit(_ limit: Int, withReply reply: @escaping (String?) -> Void) {
        do {
            try ChargeLimiter.setLimit(limit)
            reply(nil)
        } catch {
            reply("\(error)")
        }
    }

    func getLimit(withReply reply: @escaping (Int) -> Void) {
        reply(ChargeLimiter.readLimit() ?? -1)
    }

    func ping(withReply reply: @escaping (String) -> Void) {
        reply("glide-daemon \(GlideCore.version)")
    }

    func setForceDischarge(_ enabled: Bool, withReply reply: @escaping (String?) -> Void) {
        do {
            guard let client = SMC.shared else {
                reply("failed to connect to SMC")
                return
            }
            
            // Apple Silicon force discharge (disable power adapter)
            if (try? client.readKey("CHIE")) != nil {
                try client.writeKey("CHIE", bytes: enabled ? [0x08] : [0x00])
                reply(nil)
                return
            }
            
            // Intel force discharge
            if (try? client.readKey("CH0I")) != nil {
                try client.writeKey("CH0I", bytes: enabled ? [0x01] : [0x00])
                reply(nil)
                return
            }
            
            reply("No supported SMC force discharge key found on this Mac.")
        } catch {
            reply("\(error)")
        }
    }
    
    func setMagSafeLED(_ color: Int, withReply reply: @escaping (String?) -> Void) {
        do {
            guard let client = SMC.shared else {
                reply("failed to connect to SMC")
                return
            }
            
            // 0 = default behavior (let SMC decide)
            // 1 = green
            // 2 = orange
            // 3 = off
            if (try? client.readKey("ACLC")) != nil {
                try client.writeKey("ACLC", bytes: [UInt8(color)])
                reply(nil)
            } else {
                reply("MagSafe LED control not supported on this Mac (ACLC key missing).")
            }
        } catch {
            reply("\(error)")
        }
    }
}

func runService() {
    let listener = NSXPCListener(machServiceName: GlideXPC.serviceName)
    let delegate = Daemon()
    listener.delegate = delegate
    listener.resume()
    print("glide-daemon \(GlideCore.version) — listening on \(GlideXPC.serviceName)")
    RunLoop.main.run()
}

extension Daemon: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: GlideDaemonProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
}

// ---- CLI mode (for testing) ----
switch args.first {
case "set":
    guard geteuid() == 0 else { print("run with sudo"); exit(1) }
    guard let value = Int(args.count > 1 ? args[1] : "") else {
        print("usage: sudo glide-daemon set <60-100, step 5>"); exit(1)
    }
    do {
        try ChargeLimiter.setLimit(value)
        print("limit set to \(value)% — doorbell rung")
    } catch {
        print("failed: \(error)"); exit(1)
    }
case "limit":
    if let limit = ChargeLimiter.readLimit() {
        print("current limit: \(limit)%")
    } else {
        print("no limit readable (run with sudo)")
    }
case "xpc":
    // client mode — talks to the running daemon the same way the app will
    let conn = NSXPCConnection(machServiceName: GlideXPC.serviceName, options: .privileged)
    conn.remoteObjectInterface = NSXPCInterface(with: GlideDaemonProtocol.self)
    conn.resume()

    guard let proxy = conn.remoteObjectProxyWithErrorHandler({ error in
        print("XPC connection failed: \(error)")
        exit(1)
    }) as? GlideDaemonProtocol else {
        print("failed to create proxy")
        exit(1)
    }

    let done = DispatchSemaphore(value: 0)

    proxy.ping { reply in
        print("ping      → \(reply)")
        done.signal()
    }
    done.wait()

    proxy.getLimit { limit in
        print("getLimit  → \(limit)")
        done.signal()
    }
    done.wait()

    if args.count > 1, let value = Int(args[1]) {
        proxy.setLimit(value) { error in
            print("setLimit(\(value)) → \(error ?? "ok")")
            done.signal()
        }
        done.wait()
    }

    print("XPC round trip OK")
    exit(0)
default:
    runService()
}
