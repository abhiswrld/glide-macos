import Foundation
// Helper logic to be pasted into BatteryModel
func checkAutoCalibration() {
    let defaults = UserDefaults.standard
    let lastCal = defaults.double(forKey: "lastCalibrationDate")
    let lastNotif = defaults.double(forKey: "lastCalibrationNotification")
    
    let now = Date().timeIntervalSince1970
    
    // First launch? Set lastCal to now
    if lastCal == 0 {
        defaults.set(now, forKey: "lastCalibrationDate")
        return
    }
    
    // 30 days = 2592000 seconds
    if now - lastCal > 2592000 {
        // Only send notification at most once a day
        if now - lastNotif > 86400 {
            defaults.set(now, forKey: "lastCalibrationNotification")
            DispatchQueue.main.async {
                NotificationManager.shared.sendNotification(
                    title: "Battery Calibration Recommended",
                    body: "It has been over a month since your last calibration. Calibrating your battery helps maintain accurate capacity readings.",
                    identifier: "cal_invite_\(Int(now))",
                    categoryIdentifier: "CALIBRATION_INVITE"
                )
            }
        }
    }
}
