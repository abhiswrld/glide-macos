//
//  DaemonModel.swift
//  Glide
//
//  Created by Abhinav on 9/15/26.
//

import Foundation
import GlideCore

@MainActor
final class DaemonModel: ObservableObject {
    nonisolated(unsafe) static var shared: DaemonModel?

    @Published var limit: Int?
    @Published var lastError: String?
    @Published var isConnected: Bool = false

    private var conn: NSXPCConnection?

    private func connection() -> NSXPCConnection {
        if let conn { return conn }

        let c = NSXPCConnection(machServiceName: GlideXPC.serviceName, options: .privileged)
        c.remoteObjectInterface = NSXPCInterface(with: GlideDaemonProtocol.self)

        let onInvalid: () -> Void = {
            Task { @MainActor in
                DaemonModel.shared?.connectionDied()
            }
        }
        c.invalidationHandler = onInvalid
        c.resume()

        conn = c
        return c
    }

    private func connectionDied() {
        conn = nil
        limit = nil
        isConnected = false
    }

    private var proxy: GlideDaemonProtocol {
        let errorHandler: (Error) -> Void = { _ in
            Task { @MainActor in
                DaemonModel.shared?.connectionDied()
            }
        }
        let raw = connection().remoteObjectProxyWithErrorHandler(errorHandler)
        return raw as! GlideDaemonProtocol
    }

    func connect() {
        let p = proxy
        let onReply: (Int) -> Void = { limit in
            Task { @MainActor in
                guard let m = DaemonModel.shared else { return }
                m.isConnected = true
                
                let savedLimit = UserDefaults.standard.integer(forKey: "userSetChargeLimit")
                
                if limit < 0 {
                    // Fresh install
                    m.setLimit(80)
                } else if limit == 100 && savedLimit >= 60 && savedLimit < 100 {
                    // Restore previously saved limit on launch if the daemon was reset to 100
                    m.setLimit(savedLimit)
                } else {
                    m.limit = limit
                }
            }
        }
        p.getLimit(withReply: onReply)
    }

    func setLimit(_ value: Int) {
        // optimistic: value is validated locally before it ever leaves, so the
        // UI moves instantly; on a real error we re-sync from the daemon
        limit = value
        lastError = nil
        
        if value >= 60 && value < 100 {
            UserDefaults.standard.set(value, forKey: "userSetChargeLimit")
        }

        let p = proxy
        let onReply: (String?) -> Void = { error in
            Task { @MainActor in
                guard let m = DaemonModel.shared else { return }
                if let error {
                    m.lastError = error
                    m.limit = nil
                    m.connect()
                } else {
                    m.limit = value
                }
            }
        }
        p.setLimit(value, withReply: onReply)
    }

    func setForceDischarge(_ enabled: Bool) {
        let p = proxy
        p.setForceDischarge(enabled) { error in
            if let error {
                print("Failed to set force discharge: \(error)")
            }
        }
    }
    func setMagSafeLED(_ color: Int) {
        let p = proxy
        p.setMagSafeLED(color) { error in
            if let error {
                print("Failed to set MagSafe LED: \(error)")
            }
        }
    }
}
