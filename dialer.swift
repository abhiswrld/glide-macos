import Foundation
import Dispatch
import XPC

let service = "com.apple.iokit.powerdxpc"
let conn = xpc_connection_create_mach_service(service, nil, 0)

final class Box { var events: [String] = []; let lock = NSLock() }
let box = Box()

xpc_connection_set_event_handler(conn) { event in
    let c = xpc_copy_description(event)   // FIX: non-optional pointer in Swift
    let s = String(cString: c)
    free(c)
    box.lock.lock(); box.events.append(s); box.lock.unlock()
    print("◀︎ \(s)")
}
xpc_connection_resume(conn)
print("dialed \(service) as pid \(getpid())")

func wait(_ s: Double) { Thread.sleep(forTimeInterval: s) }
func dictReplies() -> Int {
    box.lock.lock(); defer { box.lock.unlock() }
    return box.events.filter { $0.hasPrefix("<dictionary") }.count
}

// Phase 1 — read-only canary: which key routes messages?
var winKey: String? = nil
for key in ["command", "cmd", "name", "type", "message"] {
    let before = dictReplies()
    let m = xpc_dictionary_create(nil, nil, 0)
    xpc_dictionary_set_string(m, key, "batteryChargingStateRequest")
    print("→ probe routing key '\(key)'")
    xpc_connection_send_message(conn, m)
    wait(1.2)
    if dictReplies() > before { winKey = key; break }
}
print(winKey.map { "routing key: \($0)" } ?? "no routing key answered")

// Phase 2 — chargeSocLimit with the CURRENT limit (85) = a no-op proof
for key in (winKey.map { [$0] } ?? ["command", "cmd", "name"]) {
    let m = xpc_dictionary_create(nil, nil, 0)
    xpc_dictionary_set_string(m, key, "chargeSocLimit")
    xpc_dictionary_set_int64(m, "soclimit", 85)
    xpc_dictionary_set_string(m, "reason", "manualChargeLimit")
    xpc_dictionary_set_bool(m, "drain", true)
    xpc_dictionary_set_bool(m, "isEndOfCharge", true)
    xpc_dictionary_set_bool(m, "noChargeToFull", false)
    xpc_dictionary_set_bool(m, "terminated", false)
    xpc_dictionary_set_int64(m, "owner", Int64(getpid()))
    var u = uuid_t(0x78,0x99,0xE4,0xE8,0xBA,0x8B,0x45,0x01,0xB7,0x50,0x75,0x19,0x04,0x2B,0x3A,0x37)
    xpc_dictionary_set_uuid(m, "token", &u)
    print("→ chargeSocLimit soclimit=85 via '\(key)' (no-op value)")
    xpc_connection_send_message(conn, m)
    wait(2.0)
}
wait(1.0)
print("done · dictionary replies: \(dictReplies())")
print("grep powerd's log for 'received SOC limit from \(getpid())'")