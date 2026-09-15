import Foundation
import GlideCore

guard geteuid() == 0 else {
    print("run with sudo")
    exit(1)
}

guard let smc = SMC.shared else {
    print("no SMC connection")
    exit(1)
}

func chltHex() -> String {
    guard let v = try? smc.readKey("CHLT"), v.bytes.count >= 3 else { return "??" }
    return v.bytes.prefix(3).map { String(format: "%02x", $0) }.joined(separator: " ")
}

func report(_ label: String) {
    let b = BatteryReader.read()
    print("\(label): battery=\(b.percent)% charging=\(b.isCharging) CHLT=[\(chltHex())]")
}

report("before        ")

guard let v = try? smc.readKey("CHLT"), v.bytes.count >= 3 else {
    print("cannot read CHLT")
    exit(1)
}
let original = Array(v.bytes.prefix(3))
print("saving original: \(original.map { String(format: "%02x", $0) }.joined(separator: " "))")

var raised = original
raised[0] = 0x5a   // limit 90

do {
    try smc.writeKey("CHLT", bytes: raised)
    print("wrote limit=90 to CHLT")
} catch {
    print("CHLT write REJECTED: \(error)")
    exit(1)
}

for i in 1...5 {
    Thread.sleep(forTimeInterval: 4)
    report("t+\(i * 4)s     ")
}

do {
    try smc.writeKey("CHLT", bytes: original)
    print("restored original CHLT")
} catch {
    print("RESTORE FAILED — open Settings and drag the charge slider to 85, apple rewrites everything cleanly: \(error)")
}

for i in 1...3 {
    Thread.sleep(forTimeInterval: 4)
    report("restored +\(i * 4)s")
}
