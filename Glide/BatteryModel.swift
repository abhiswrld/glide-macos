import Foundation
import GlideCore
import IOKit.pwr_mgt

// MARK: - History Entry

struct BatteryHistoryEntry: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let healthPercent: Int
    let cycleCount: Int
}


// MARK: - Short Term History Entry

struct ShortTermBatteryEntry: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let percent: Int
}

// MARK: - Battery Model

@MainActor
final class BatteryModel: ObservableObject {

    @Published var snapshot: BatterySnapshot?
    @Published var history: [BatteryHistoryEntry] = []
    @Published var shortTermHistory: [ShortTermBatteryEntry] = []

    var onUpdate: ((BatterySnapshot) -> Void)?

    private var lastPluggedIn: Bool?
    private var powerChangedAt = Date()
    private var sleepAssertionID: IOPMAssertionID = 0
    private var lastSetLEDColor: Int = -1

    private var isUIVisible: Bool = false
    private var pollingTask: Task<Void, Never>?

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
    
    func setUIVisibility(_ visible: Bool) {
        if isUIVisible == visible { return }
        isUIVisible = visible
        startPolling()
    }


    func start() {
        history = Self.loadHistory()
        shortTermHistory = Self.loadShortTermHistory()
        refresh()
        startPolling()
    }

    
    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor in
            while !Task.isCancelled {
                // Sleep for 10s if UI is visible, 60s if hidden to save battery
                let delay: UInt64 = isUIVisible ? 10 : 60
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                if Task.isCancelled { break }
                refresh()
            }
        }
    }

    func refresh() {
        let s = BatteryReader.read()
        if s.isPluggedIn != lastPluggedIn {
            if let last = lastPluggedIn, last == true && s.isPluggedIn == false {
                SmartChargingModel.shared.recordUnplug()
            }
            lastPluggedIn = s.isPluggedIn
            powerChangedAt = Date()
        }
        if snapshot != s {
            snapshot = s
        }
        onUpdate?(s)
        logIfNeeded(s)
        
        handleHeatProtection(s)
        if !UserDefaults.standard.bool(forKey: "isHeatProtecting") {
            if handleCalibration(s) { return }
            if handleForceDischarge(s) { return }
            if handleSmartCharging(s) { return }
            handleSailing(s)
        }
        
        manageMagSafeLED()
    }


    private func handleHeatProtection(_ s: BatterySnapshot) {
        let defaults = UserDefaults.standard
        let hpEnabled = defaults.bool(forKey: "heatProtectionEnabled")
        let isHeatProtecting = defaults.bool(forKey: "isHeatProtecting")
        
        if !hpEnabled {
            if isHeatProtecting {
                defaults.set(false, forKey: "isHeatProtecting")
            }
            return
        }
        
        let thresholdRaw = defaults.integer(forKey: "heatProtectionThreshold")
        let threshold = thresholdRaw == 0 ? 35 : thresholdRaw
        let currentTemp = s.temperatureC ?? 0
        
        if !isHeatProtecting {
            if currentTemp > Double(threshold) {
                defaults.set(true, forKey: "isHeatProtecting")
                let pauseLimit = max(60, s.percent - (s.percent % 5))
                DaemonModel.shared?.setLimit(pauseLimit)
                
                Task { @MainActor in
                    NotificationManager.shared.sendNotification(
                        title: "Charging Paused",
                        body: "Battery temperature exceeded limit. Charging will resume once cooled down.",
                        identifier: "heatProtection"
                    )
                }
            }
        } else {
            // Cool down: Give it a 2-degree hysteresis so it doesn't bounce
            if currentTemp <= Double(threshold - 2) {
                defaults.set(false, forKey: "isHeatProtecting")
                
                Task { @MainActor in
                    NotificationManager.shared.sendNotification(
                        title: "Charging Resumed",
                        body: "Battery has cooled down.",
                        identifier: "heatProtection"
                    )
                }
                
                // Restoring the limit is handled seamlessly by handleSailing's failsafe on the next tick!
            } else {
                // Ensure the pause limit is maintained
                let pauseLimit = max(60, s.percent - (s.percent % 5))
                if let currentLimit = DaemonModel.shared?.limit, currentLimit != pauseLimit {
                    DaemonModel.shared?.setLimit(pauseLimit)
                }
            }
        }
    }
    
    private func handleSmartCharging(_ s: BatterySnapshot) -> Bool {
        let defaults = UserDefaults.standard
        let isEnabled = defaults.bool(forKey: "smartChargingEnabled")
        let isSmartPausing = defaults.bool(forKey: "isSmartPausing")
        let smartModel = SmartChargingModel.shared
        
        if !isEnabled {
            if isSmartPausing {
                defaults.set(false, forKey: "isSmartPausing")
            }
            return false
        }
        
        guard s.isPluggedIn else {
            if isSmartPausing {
                defaults.set(false, forKey: "isSmartPausing")
            }
            return false
        }
        
        guard let targetDate = smartModel.predictedUnplugTime else {
            if isSmartPausing {
                defaults.set(false, forKey: "isSmartPausing")
            }
            return false
        }
        
        let timeRemaining = targetDate.timeIntervalSince(Date())
        let primaryLimitRaw = defaults.integer(forKey: "primaryChargeLimit")
        let primaryLimit = primaryLimitRaw == 0 ? 80 : primaryLimitRaw
        
        // If > 1.5 hours away
        if timeRemaining > 5400 {
            if s.percent >= primaryLimit {
                // We reached the user's base limit, pause there
                if !isSmartPausing {
                    defaults.set(true, forKey: "isSmartPausing")
                }
                if let currentLimit = DaemonModel.shared?.limit, currentLimit != primaryLimit {
                    DaemonModel.shared?.setLimit(primaryLimit)
                }
                return true
            } else {
                // Keep charging up to the primary limit
                if isSmartPausing {
                    defaults.set(false, forKey: "isSmartPausing")
                }
                return false // Let sailing or standard charging handle getting to primaryLimit
            }
        } else if timeRemaining > 0 {
            // Less than 1.5 hours away, charge to 100%
            if isSmartPausing {
                defaults.set(false, forKey: "isSmartPausing")
            }
            if let currentLimit = DaemonModel.shared?.limit, currentLimit != 100 {
                DaemonModel.shared?.setLimit(100)
            }
            return true
        } else {
            // Target passed
            if isSmartPausing {
                defaults.set(false, forKey: "isSmartPausing")
            }
            return false
        }
    }

    private func handleSailing(_ s: BatterySnapshot) {
        let defaults = UserDefaults.standard
        let sailingEnabled = defaults.bool(forKey: "sailingEnabled")
        let isSailing = defaults.bool(forKey: "isSailing")
        
        let primaryLimitRaw = defaults.integer(forKey: "primaryChargeLimit")
        let primaryLimit = primaryLimitRaw == 0 ? 80 : primaryLimitRaw

        if !sailingEnabled {
            if isSailing {
                defaults.set(false, forKey: "isSailing")
            }
            // Always ensure daemon matches user's primary limit when sailing is OFF
            if let currentLimit = DaemonModel.shared?.limit, currentLimit != primaryLimit {
                DaemonModel.shared?.setLimit(primaryLimit)
            }
            return
        }

        let lowerLimitRaw = defaults.integer(forKey: "sailingLowerLimit")
        let lowerLimit = lowerLimitRaw == 0 ? 75 : lowerLimitRaw
        if lowerLimit == 0 || primaryLimit == 0 { return }

        if !isSailing {
            // Start sailing when battery reaches the user's primary limit
            if s.percent >= primaryLimit, lowerLimit < primaryLimit {
                defaults.set(true, forKey: "isSailing")
                DaemonModel.shared?.setLimit(lowerLimit)
            } else {
                // Failsafe: Ensure daemon is targeting the primary limit to charge up
                if let currentLimit = DaemonModel.shared?.limit, currentLimit != primaryLimit {
                    DaemonModel.shared?.setLimit(primaryLimit)
                }
            }
        } else {
            // Stop sailing when battery drains to the lower limit
            if s.percent <= lowerLimit {
                defaults.set(false, forKey: "isSailing")
                DaemonModel.shared?.setLimit(primaryLimit)
            } else {
                // Failsafe: Ensure daemon is targeting the lower limit to discharge
                if let currentLimit = DaemonModel.shared?.limit, currentLimit != lowerLimit {
                    DaemonModel.shared?.setLimit(lowerLimit)
                }
            }
        }
    }

    private func handleForceDischarge(_ s: BatterySnapshot) -> Bool {
        let defaults = UserDefaults.standard
        let fdEnabled = defaults.bool(forKey: "forceDischargeEnabled")
        let isForceDischarging = defaults.bool(forKey: "isForceDischarging")
        
        if !fdEnabled {
            if isForceDischarging {
                defaults.set(false, forKey: "isForceDischarging")
                DaemonModel.shared?.setForceDischarge(false)
            }
            return false
        }
        
        if s.percent <= 20 {
            defaults.set(false, forKey: "forceDischargeEnabled")
            if isForceDischarging {
                defaults.set(false, forKey: "isForceDischarging")
                DaemonModel.shared?.setForceDischarge(false)
            }
            return false
        }
        
        if !isForceDischarging {
            defaults.set(true, forKey: "isForceDischarging")
            DaemonModel.shared?.setForceDischarge(true)
        }
        
        return true
    }

    private func handleCalibration(_ s: BatterySnapshot) -> Bool {
        let defaults = UserDefaults.standard
        let phase = defaults.integer(forKey: "calibrationPhase") // 0=off, 1=charge, 2=discharge
        
        if phase == 0 {
            manageSleepAssertion(active: false)
            return false
        }
        
        manageSleepAssertion(active: true)
        
        if phase == 1 {
            // Phase 1: Charge to 100%
            if let currentLimit = DaemonModel.shared?.limit, currentLimit != 100 {
                DaemonModel.shared?.setLimit(100)
            }
            
            if s.isFull || s.percent >= 100 {
                defaults.set(2, forKey: "calibrationPhase")
                DaemonModel.shared?.setForceDischarge(true)
            }
            return true
        }
        
        if phase == 2 {
            // Phase 2: Force Discharge to 10%
            if s.percent <= 10 {
                let primaryLimitRaw = defaults.integer(forKey: "primaryChargeLimit")
                let primaryLimit = primaryLimitRaw == 0 ? 80 : primaryLimitRaw
                
                defaults.set(0, forKey: "calibrationPhase")
                
                Task { @MainActor in
                    NotificationManager.shared.sendNotification(
                        title: "Calibration Complete",
                        body: "Your battery has been successfully calibrated.",
                        identifier: "calibrationComplete"
                    )
                }
                
                DaemonModel.shared?.setForceDischarge(false)
                DaemonModel.shared?.setLimit(primaryLimit)
            }
            return true
        }
        
        return false
    }

    private func manageSleepAssertion(active: Bool) {
        if active {
            if sleepAssertionID == 0 {
                IOPMAssertionCreateWithName(
                    kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                    "Glide Battery Calibration" as CFString,
                    &sleepAssertionID
                )
            }
        } else {
            if sleepAssertionID != 0 {
                IOPMAssertionRelease(sleepAssertionID)
                sleepAssertionID = 0
            }
        }
    }

    private func manageMagSafeLED() {
        let enabled = UserDefaults.standard.bool(forKey: "magsafeLEDControlEnabled")
        let targetColor: Int
        if !enabled {
            targetColor = 0
        } else {
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: "isForceDischarging") || defaults.bool(forKey: "isSailing") {
                targetColor = 1
            } else {
                targetColor = 0
            }
        }
        
        if targetColor != lastSetLEDColor {
            lastSetLEDColor = targetColor
            DaemonModel.shared?.setMagSafeLED(targetColor)
        }
    }

    // MARK: - History Persistence

    private static let historyURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Glide", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()


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

    private static func loadHistory() -> [BatteryHistoryEntry] {
        guard FileManager.default.fileExists(atPath: historyURL.path),
              let data = try? Data(contentsOf: historyURL)
        else { return [] }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let entries = try? decoder.decode([BatteryHistoryEntry].self, from: data) else { return [] }
        return entries
    }

    private static func saveHistory(_ entries: [BatteryHistoryEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: historyURL, options: .atomic)
    }
}
