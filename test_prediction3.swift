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
let todayWeekday = cal.component(.weekday, from: now)

// We will inject an unplug event at 12:30 PM (12.5 hours since midnight) for every Friday (or whatever today's weekday is) over the last 3 weeks.
let targetTime = 12.5 * 3600.0

for i in 0..<4 {
    let pastDate = cal.date(byAdding: .day, value: -(i * 7), to: now)!
    let pastStart = cal.startOfDay(for: pastDate)
    
    // Exact 12:30 PM
    let event = UnplugEvent(id: UUID(), date: pastStart.addingTimeInterval(targetTime), weekday: todayWeekday, timeSinceMidnight: targetTime)
    events.append(event)
}

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let data = try! encoder.encode(events)

let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let dir = support.appendingPathComponent("Glide", isDirectory: true)
let file = dir.appendingPathComponent("smart_charging_events.json")
try! data.write(to: file)

print("Injected fake history for today's weekday at 12:30 PM into \(file.path)")
