import Foundation
import SwiftUI

struct UnplugEvent: Codable, Identifiable {
    var id: UUID = UUID()
    let date: Date
    let weekday: Int
    let timeSinceMidnight: TimeInterval
}

@MainActor
final class SmartChargingModel: ObservableObject {
    static let shared = SmartChargingModel()
    
    @Published var events: [UnplugEvent] = []
    @Published var userOverrideTime: Date? = nil
    @Published var predictedUnplugTime: Date? = nil
    
    private let eventsURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Glide", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("smart_charging_events.json")
    }()
    
    init() {
        loadEvents()
        calculateNextUnplug()
        
        // Timer to recalculate periodically to clear old overrides
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.calculateNextUnplug()
            }
        }
    }
    
    func recordUnplug(at date: Date = Date()) {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let startOfDay = cal.startOfDay(for: date)
        let timeSinceMidnight = date.timeIntervalSince(startOfDay)
        
        let event = UnplugEvent(date: date, weekday: weekday, timeSinceMidnight: timeSinceMidnight)
        events.append(event)
        
        // Keep only last 60 days
        let cutoff = cal.date(byAdding: .day, value: -60, to: date)!
        events = events.filter { $0.date >= cutoff }
        
        saveEvents()
        calculateNextUnplug()
    }
    
    func overridePrediction(to time: Date) {
        userOverrideTime = time
        calculateNextUnplug()
    }
    
    func calculateNextUnplug() {
        let now = Date()
        
        if let override = userOverrideTime {
            if override > now {
                predictedUnplugTime = override
                return
            } else {
                userOverrideTime = nil
            }
        }
        
        let cal = Calendar.current
        
        // Look up to 2 days ahead
        for dayOffset in 0...2 {
            guard let targetDate = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let weekday = cal.component(.weekday, from: targetDate)
            let targetStartOfDay = cal.startOfDay(for: targetDate)
            
            let dayEvents = events.filter { $0.weekday == weekday }
            if dayEvents.count >= 2 {
                let sortedTimes = dayEvents.map { $0.timeSinceMidnight }.sorted()
                let medianTime = sortedTimes[sortedTimes.count / 2]
                let candidateTime = targetStartOfDay.addingTimeInterval(medianTime)
                
                if candidateTime > now {
                    let meanTime = sortedTimes.reduce(0, +) / Double(sortedTimes.count)
                    let variance = sortedTimes.reduce(0) { $0 + pow($1 - meanTime, 2) } / Double(sortedTimes.count)
                    let stdDev = sqrt(variance)
                    
                    // Standard deviation < 2.5 hours (9000s) = predictable
                    if stdDev <= 9000 {
                        predictedUnplugTime = candidateTime
                        return
                    }
                }
            }
        }
        
        predictedUnplugTime = nil
    }
    
    private func loadEvents() {
        guard FileManager.default.fileExists(atPath: eventsURL.path),
              let data = try? Data(contentsOf: eventsURL) else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let decoded = try? decoder.decode([UnplugEvent].self, from: data) {
            self.events = decoded
        }
    }
    
    private func saveEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(events) else { return }
        try? data.write(to: eventsURL, options: .atomic)
    }
}
