//
//  ChargeLimiter.swift
//  GlideCore
//
//  Created by Abhinav on 9/15/26.
//

import Foundation

/// The charge-limit lever, validated on GG27:
/// mclLimitValue in the smartcharging domain through cfprefsd, then the
/// notifyd doorbell so PowerUIAgent re-submits to powerd.
/// Needs root. Apple only accepts multiples of 5.
public enum ChargeLimiter {

    public enum LimitError: Error, CustomStringConvertible {
        case notRoot
        case invalidValue(Int)
        case writeFailed

        public var description: String {
            switch self {
            case .notRoot: return "must run as root"
            case .invalidValue(let v): return "\(v) rejected — 60 to 100, steps of 5"
            case .writeFailed: return "cfprefsd rejected the write"
            }
        }
    }

    public static let domain = "com.apple.smartcharging.topoffprotection"
    public static let key = "mclLimitValue"
    public static let doorbell = "com.apple.smartcharging.defaultschanged"
    public static let doorbell2 = "com.apple.powerui.smartcharge"

    /// apple only honors detents; probe 60 during testing, adjust if needed
    public static let allowedValues = Array(stride(from: 60, through: 100, by: 5))

    public static func setLimit(_ limit: Int) throws {
        guard geteuid() == 0 else { throw LimitError.notRoot }
        guard allowedValues.contains(limit) else { throw LimitError.invalidValue(limit) }

        CFPreferencesSetValue(
            key as CFString,
            NSNumber(value: limit),
            domain as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        guard CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw LimitError.writeFailed
        }
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(doorbell as CFString), nil, nil, true)
        CFNotificationCenterPostNotification(center, CFNotificationName(doorbell2 as CFString), nil, nil, true)
    }

    /// only meaningful when running as root (domain lives in /var/root)
    public static func readLimit() -> Int? {
        let value = CFPreferencesCopyValue(
            key as CFString,
            domain as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) as? NSNumber
        return value?.intValue
    }
}
