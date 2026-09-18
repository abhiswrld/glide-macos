import Foundation
import Sparkle

@MainActor
final class SparkleManager: ObservableObject {
    static let shared = SparkleManager()
    
    let updaterController: SPUStandardUpdaterController
    
    private init() {
        // Starts the updater automatically
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
