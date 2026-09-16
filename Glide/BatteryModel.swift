import Foundation
import GlideCore

// MARK: - History Entry

struct BatteryHistoryEntry: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let healthPercent: Int
    let cycleCount: Int
}

// MARK: - Battery Model

@MainActor
final class BatteryModel: ObservableObject {
    @Published var snapshot: BatterySnapshot?
    @Published var history: [BatteryHistoryEntry] = []
    var onUpdate: ((BatterySnapshot) -> Void)?

    private var lastPluggedIn: Bool?
    private var powerChangedAt = Date()

    /// nil until the power state has been stable long enough for a real estimate
    var timeRemaining: String? {
        guard let s = snapshot,
              !s.isPluggedIn,
              !s.isCharging,
              let t = s.timeRemainingMinutes,
              t > 5, t < 960,
              Date().timeIntervalSince(powerChangedAt) > 45
        else { return nil }
        return "\(t / 60):\(String(format: "%02d", t % 60)) remaining"
    }

    func start() {
        history = Self.loadHistory()
        refresh()
        Task { @MainActor in
            while true {
                try? await Task.sleep(for: .seconds(3))
                refresh()
            }
        }
    }

    func refresh() {
        let s = BatteryReader.read()
        if s.isPluggedIn != lastPluggedIn {
            lastPluggedIn = s.isPluggedIn
            powerChangedAt = Date()
        }
        snapshot = s
        onUpdate?(s)
        logIfNeeded(s)
    }

    // MARK: - History Persistence

    private static let historyURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Glide", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    private func logIfNeeded(_ s: BatterySnapshot) {
        guard let health = s.healthPercent else { return }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Only log once per day
        if let last = history.last, cal.isDate(last.date, inSameDayAs: today) {
            return
        }

        let entry = BatteryHistoryEntry(
            date: today,
            healthPercent: health,
            cycleCount: s.cycleCount
        )
        history.append(entry)
        Self.saveHistory(history)
    }

    private static func loadHistory() -> [BatteryHistoryEntry] {
        guard FileManager.default.fileExists(atPath: historyURL.path),
              let data = try? Data(contentsOf: historyURL),
              let entries = try? JSONDecoder().decode([BatteryHistoryEntry].self, from: data)
        else { return [] }
        return entries
    }

    private static func saveHistory(_ entries: [BatteryHistoryEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: historyURL, options: .atomic)
    }
}
