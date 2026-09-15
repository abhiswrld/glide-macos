import Foundation
import GlideCore

let b = BatteryReader.read()
print("battery: \(b.percent)% · cycles=\(b.cycleCount) · health=\(b.healthPercent.map { "\($0)%" } ?? "nil") · temp=\(b.temperatureC.map { String(format: "%.1f°C", $0) } ?? "nil") · power=\(b.watts.map { String(format: "%.2fW", $0) } ?? "nil")")

print("--- SMC selector sweep ---")
for selector in 0..<32 {
    var buf = [UInt8](repeating: 0, count: 80)
    let key: [UInt8] = Array("#KEY".utf8)
    for i in 0..<4 { buf[i] = key[i] }
    buf[8] = 9

    let r = SMC.rawStructCall(UInt32(selector), input: buf)
    if r.kr == KERN_SUCCESS {
        let hex = r.out.prefix(48).map { String(format: "%02x", $0) }.joined(separator: " ")
        print("selector \(selector): OK \(hex)")
    }
}
print("--- sweep done ---")
