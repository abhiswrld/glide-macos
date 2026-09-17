import Foundation
import IOKit

public struct BatterySnapshot: Codable, Sendable, Equatable {
    public let timestamp: Date
    public let percent: Int
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let isFull: Bool
    public let cycleCount: Int
    public let healthPercent: Int?
    public let temperatureC: Double?
    public let watts: Double?
    public let timeRemainingMinutes: Int?
    public let raw: [String: Int]

    public static func == (lhs: BatterySnapshot, rhs: BatterySnapshot) -> Bool {
        return lhs.percent == rhs.percent &&
               lhs.isCharging == rhs.isCharging &&
               lhs.isPluggedIn == rhs.isPluggedIn &&
               lhs.isFull == rhs.isFull &&
               lhs.cycleCount == rhs.cycleCount &&
               lhs.healthPercent == rhs.healthPercent
    }

}

public enum BatteryReader {
    public static func read() -> BatterySnapshot {
        var raw: [String: Int] = [:]

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != IO_OBJECT_NULL {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let cfDict = props?.takeRetainedValue(),
               let dict = (cfDict as NSDictionary) as? [String: Any] {
                for (key, value) in dict {
                    guard let k = key as? String else { continue }
                    if let n = (value as? NSNumber)?.intValue {
                        raw[k] = n
                    } else if let sub = value as? NSDictionary {
                        for (sk, sv) in sub {
                            if let sk = sk as? String, let sn = (sv as? NSNumber)?.intValue {
                                raw["\(k).\(sk)"] = sn
                            }
                        }
                    }
                }
            }
            IOObjectRelease(service)
        }

        let design = raw["BatteryData.DesignCapacity"] ?? raw["DesignCapacity"]
        let full = raw["BatteryData.FullChargeCapacity"] ?? raw["AppleRawMaxCapacity"]

        let health: Int?
        if let design, design > 0, let full, full > 200 {
            health = min(100, Int((Double(full) / Double(design) * 100).rounded()))
        } else {
            health = nil
        }

        let tempC: Double? = raw["Temperature"].map { Double($0) / 100.0 } ?? SMC.batteryTemperatureC()

        let watts: Double?
        if let amps = raw["Amperage"], let volts = raw["Voltage"] {
            watts = Double(amps) * Double(volts) / 1_000_000
        } else {
            watts = nil
        }

        let timeRemaining = raw["TimeRemaining"] ?? -1

        return BatterySnapshot(
            timestamp: Date(),
            percent: raw["CurrentCapacity"] ?? 0,
            isCharging: (raw["IsCharging"] ?? 0) == 1,
            isPluggedIn: (raw["ExternalConnected"] ?? 0) == 1,
            isFull: (raw["FullyCharged"] ?? 0) == 1,
            cycleCount: raw["CycleCount"] ?? 0,
            healthPercent: health,
            temperatureC: tempC,
            watts: watts,
            timeRemainingMinutes: timeRemaining > 0 ? timeRemaining : nil,
            raw: raw
        )
    }
}
