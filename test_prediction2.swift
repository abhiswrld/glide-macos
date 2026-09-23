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

// For EVERY day of the week, inject an unplug event at 8:30 AM
for dayOffset in -21...0 {
    let pastDate = cal.date(byAdding: .day, value: dayOffset, to: now)!
    let pastStart = cal.startOfDay(for: pastDate)
    
    let targetTime = 8.5 * 3600.0 // 8:30 AM
    let jitter = Double.random(in: -300...300) // +/- 5 mins
    
    let event = UnplugEvent(id: UUID(), date: pastStart.addingTimeInterval(targetTime + jitter), weekday: cal.component(.weekday, from: pastDate), timeSinceMidnight: targetTime + jitter)
    events.append(event)
}

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let data = try! encoder.encode(events)

let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let dir = support.appendingPathComponent("Glide", isDirectory: true)
let file = dir.appendingPathComponent("smart_charging_events.json")
try! data.write(to: file)

print("Injected fake history for every day of the week at 8:30 AM into \(file.path)")
