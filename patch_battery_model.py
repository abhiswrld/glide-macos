import re

file_path = "/Users/abhinav/Documents/Glide/Glide/BatteryModel.swift"
with open(file_path, "r") as f:
    content = f.read()

# Add ShortTermBatteryEntry
struct_str = """
// MARK: - Short Term History Entry

struct ShortTermBatteryEntry: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let percent: Int
}
"""
content = content.replace("// MARK: - Battery Model", struct_str + "\n// MARK: - Battery Model")

# Add property
prop_str = """
    @Published var snapshot: BatterySnapshot?
    @Published var history: [BatteryHistoryEntry] = []
    @Published var shortTermHistory: [ShortTermBatteryEntry] = []
"""
content = content.replace("    @Published var snapshot: BatterySnapshot?\n    @Published var history: [BatteryHistoryEntry] = []", prop_str)

# Load it in start()
start_str = """
    func start() {
        history = Self.loadHistory()
        shortTermHistory = Self.loadShortTermHistory()
        refresh()
        startPolling()
    }
"""
content = re.sub(r'    func start\(\) \{\n.*?startPolling\(\)\n    \}', start_str, content, flags=re.DOTALL)

# Add save/load functions
funcs_str = """
    private static func loadShortTermHistory() -> [ShortTermBatteryEntry] {
        guard let data = UserDefaults.standard.data(forKey: "glideShortTermHistory"),
              let decoded = try? JSONDecoder().decode([ShortTermBatteryEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveShortTermHistory() {
        if let encoded = try? JSONEncoder().encode(shortTermHistory) {
            UserDefaults.standard.set(encoded, forKey: "glideShortTermHistory")
        }
    }
"""
content = content.replace("    private static func loadHistory() -> [BatteryHistoryEntry] {", funcs_str + "\n    private static func loadHistory() -> [BatteryHistoryEntry] {")

# Add to logIfNeeded
log_str = """
    private func logIfNeeded(_ s: BatterySnapshot) {
        // Short-term logging (every 2 minutes)
        if let lastShort = shortTermHistory.last {
            if Date().timeIntervalSince(lastShort.date) > 120 {
                shortTermHistory.append(ShortTermBatteryEntry(date: Date(), percent: s.percent))
                // Prune older than 24 hours
                let cutoff = Date().addingTimeInterval(-24 * 3600)
                shortTermHistory = shortTermHistory.filter { $0.date >= cutoff }
                saveShortTermHistory()
            }
        } else {
            shortTermHistory.append(ShortTermBatteryEntry(date: Date(), percent: s.percent))
            saveShortTermHistory()
        }

        // Long-term logging
"""
content = content.replace("    private func logIfNeeded(_ s: BatterySnapshot) {\n        guard let health = s.healthPercent else { return }", log_str + "        guard let health = s.healthPercent else { return }")


with open(file_path, "w") as f:
    f.write(content)
