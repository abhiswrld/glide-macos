import Foundation
import GlideCore

@MainActor
final class BatteryModel: ObservableObject {
    @Published var snapshot: BatterySnapshot?
    var onUpdate: ((BatterySnapshot) -> Void)?

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
        snapshot = s
        onUpdate?(s)
    }
}
