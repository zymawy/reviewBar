import Foundation
import Sparkle

/// Manages Sparkle auto-updates
@MainActor
final class UpdateController: ObservableObject {
    static let shared = UpdateController()
    
    private let updaterController: SPUStandardUpdaterController
    
    // Publish available updates so UI can react
    @Published var canCheckForUpdates = true
    
    init() {
        // Initialize Sparkle
        // Note: Sparkle requires Info.plist keys to be set:
        // - SUFeedURL
        // - SUPublicEDKey
        
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // Monitor updater state
        self.updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    /// Trigger a user-initiated update check
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    
    /// Check automatically in background
    func checkForUpdatesInBackground() {
        updaterController.updater.checkForUpdatesInBackground()
    }
    
    /// Enable/Disable automatic checks
    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }
    
    /// Enable/Disable automatic downloading
    var automaticallyDownloadsUpdates: Bool {
        get { updaterController.updater.automaticallyDownloadsUpdates }
        set { updaterController.updater.automaticallyDownloadsUpdates = newValue }
    }
}
