import Foundation
import GlideCore

@MainActor
final class BatteryModel: ObservableObject {
    @Published var snapshot: BatterySnapshot?
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
    }
}
