import Foundation
import GlideCore

print("running as \(geteuid() == 0 ? "root" : "regular user")")

let b = BatteryReader.read()
print("battery: \(b.percent)% · charging=\(b.isCharging) · cycles=\(b.cycleCount) · health=\(b.healthPercent.map { "\($0)%" } ?? "nil") · temp=\(b.temperatureC.map { String(format: "%.1f°C", $0) } ?? "nil") · power=\(b.watts.map { String(format: "%.2fW", $0) } ?? "nil")")

print("--- SMC probes ---")
for key in ["#KEY", "TB0T", "TB1T", "TB2T", "CH0B", "CH0C", "CH0I", "CHWA"] {
    print("SMC[\(key)] \(SMC.probe(key))")
}
print("--- done ---")
