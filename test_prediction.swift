import Foundation

struct UnplugEvent: Codable {
    let id: UUID
    let date: Date
    let weekday: Int
    let timeSinceMidnight: TimeInterval
}

let cal = Calendar.current
var events: [UnplugEvent] = []
let now = Date()
let startOfDay = cal.startOfDay(for: now)

// Add 5 events for today's weekday, clustered around 8:30 AM (8.5 * 3600 = 30600)
for i in 1...5 {
    let pastDate = cal.date(byAdding: .day, value: -i*7, to: now)!
    let pastStart = cal.startOfDay(for: pastDate)
    
    // Add some jitter (e.g. +/- 10 minutes)
    let jitter = Double.random(in: -600...600)
    let targetTime = 30600.0 + jitter
    
    let event = UnplugEvent(id: UUID(), date: pastStart.addingTimeInterval(targetTime), weekday: cal.component(.weekday, from: pastDate), timeSinceMidnight: targetTime)
    events.append(event)
}

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let data = try! encoder.encode(events)

let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let dir = support.appendingPathComponent("Glide", isDirectory: true)
let file = dir.appendingPathComponent("smart_charging_events.json")
try! data.write(to: file)

print("Injected fake history for 8:30 AM unplug times into \(file.path)")
