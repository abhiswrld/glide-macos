import AppKit
let levels = ["battery.0", "battery.25", "battery.50", "battery.75", "battery.100"]
for l in levels {
    let name = "\(l).bolt"
    let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    print("\(name) exists: \(img != nil)")
}
