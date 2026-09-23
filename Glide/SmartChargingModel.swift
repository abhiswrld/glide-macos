import Foundation
import SwiftUI

struct UnplugEvent: Codable, Identifiable {
    var id: UUID = UUID()
    let date: Date
    let weekday: Int
    let timeSinceMidnight: TimeInterval
    var chargeLevel: Int?
}

struct ManualScheduleEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var timeSinceMidnight: TimeInterval
    var chargeLevel: Int
}

@MainActor
final class SmartChargingModel: ObservableObject {
    static let shared = SmartChargingModel()
    
    @Published var events: [UnplugEvent] = []
    @Published var manualSchedule: [Int: [ManualScheduleEntry]] = [:] // 1 (Sun) ... 7 (Sat) -> Array of schedules
    @Published var predictedUnplugTime: Date? = nil
    @Published var predictedChargeLevel: Int? = nil
    
    private let eventsURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Glide", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("smart_charging_events.json")
    }()
    
    private let scheduleURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Glide", isDirectory: true)
        return dir.appendingPathComponent("smart_charging_schedule.json")
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
    
    func recordUnplug(at date: Date = Date(), chargeLevel: Int = 100) {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let startOfDay = cal.startOfDay(for: date)
        let timeSinceMidnight = date.timeIntervalSince(startOfDay)
        
        let event = UnplugEvent(date: date, weekday: weekday, timeSinceMidnight: timeSinceMidnight, chargeLevel: chargeLevel)
        events.append(event)
        
        // Keep only last 60 days
        let cutoff = cal.date(byAdding: .day, value: -60, to: date)!
        events = events.filter { $0.date >= cutoff }
        
        saveEvents()
        calculateNextUnplug()
    }
    

    
    func calculateNextUnplug() {
        let now = Date()
        
        let cal = Calendar.current
        
        // Look up to 2 days ahead
        for dayOffset in 0...2 {
            guard let targetDate = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let weekday = cal.component(.weekday, from: targetDate)
            let targetStartOfDay = cal.startOfDay(for: targetDate)
            
            // 1. Check for manual schedule first
            if let schedules = manualSchedule[weekday], !schedules.isEmpty {
                let sortedSchedules = schedules.sorted { $0.timeSinceMidnight < $1.timeSinceMidnight }
                var foundManual = false
                
                for schedule in sortedSchedules {
                    let hour = Int(schedule.timeSinceMidnight) / 3600
                    let minute = (Int(schedule.timeSinceMidnight) % 3600) / 60
                    
                    guard let candidateTime = cal.date(bySettingHour: hour, minute: minute, second: 0, of: targetStartOfDay) else { continue }
                    
                    if candidateTime > now {
                        predictedUnplugTime = candidateTime
                        predictedChargeLevel = schedule.chargeLevel
                        foundManual = true
                        break
                    }
                }
                
                if foundManual {
                    return
                }
            }
            
            // 2. Fallback to ML learned events
            let dayEvents = events.filter { $0.weekday == weekday }
            if dayEvents.count >= 2 {
                let sortedTimes = dayEvents.map { $0.timeSinceMidnight }.sorted()
                let medianTime = sortedTimes[sortedTimes.count / 2]
                let hour = Int(medianTime) / 3600
                let minute = (Int(medianTime) % 3600) / 60
                
                guard let candidateTime = cal.date(bySettingHour: hour, minute: minute, second: 0, of: targetStartOfDay) else { continue }
                
                if candidateTime > now {
                    let meanTime = sortedTimes.reduce(0, +) / Double(sortedTimes.count)
                    let variance = sortedTimes.reduce(0) { $0 + pow($1 - meanTime, 2) } / Double(sortedTimes.count)
                    let stdDev = sqrt(variance)
                    
                    // Standard deviation < 2.5 hours (9000s) = predictable
                    if stdDev <= 9000 {
                        predictedUnplugTime = candidateTime
                        
                        let sortedLevels = dayEvents.compactMap { $0.chargeLevel }.sorted()
                        let medianLevel = sortedLevels.isEmpty ? 100 : sortedLevels[sortedLevels.count / 2]
                        predictedChargeLevel = medianLevel
                        
                        return
                    }
                }
            }
        }
        
        predictedUnplugTime = nil
        predictedChargeLevel = nil
    }
    
    func saveManualSchedule() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(manualSchedule) else { return }
        try? data.write(to: scheduleURL, options: .atomic)
        calculateNextUnplug()
    }
    
    private func loadEvents() {
        if FileManager.default.fileExists(atPath: scheduleURL.path),
           let data = try? Data(contentsOf: scheduleURL),
           let decoded = try? JSONDecoder().decode([Int: [ManualScheduleEntry]].self, from: data) {
            self.manualSchedule = decoded
        }
        
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
