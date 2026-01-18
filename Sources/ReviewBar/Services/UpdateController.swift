import Foundation
import AppKit
import Sparkle

/// Manages Sparkle auto-updates
@MainActor
final class UpdateController: ObservableObject {
    static let shared = UpdateController()
    
    private var updaterController: SPUStandardUpdaterController?
    
    // Publish available updates so UI can react
    @Published var canCheckForUpdates = false
    @Published var isConfigured = false
    
    init() {
        // Sparkle requires Info.plist keys:
        // - SUFeedURL
        // - SUPublicEDKey
        // Only initialize if we're in a proper app bundle
        
        guard Bundle.main.bundleIdentifier != nil,
              Bundle.main.infoDictionary?["SUFeedURL"] != nil else {
            print("UpdateController: Running in dev mode (no SUFeedURL). Updates disabled.")
            return
        }
        
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        self.isConfigured = true
        
        // Monitor updater state
        self.updaterController?.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    /// Trigger a user-initiated update check
    func checkForUpdates() {
        guard isConfigured else {
            // Show alert in dev mode
            let alert = NSAlert()
            alert.messageText = "Updates Not Available"
            alert.informativeText = "Auto-updates are only available in the packaged .app release. You're running in development mode.\n\nTo get the packaged app, run:\n./Scripts/package_app.sh"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        updaterController?.checkForUpdates(nil)
    }
    
    /// Check automatically in background
    func checkForUpdatesInBackground() {
        guard isConfigured else { return }
        updaterController?.updater.checkForUpdatesInBackground()
    }
    
    /// Enable/Disable automatic checks
    var automaticallyChecksForUpdates: Bool {
        get { updaterController?.updater.automaticallyChecksForUpdates ?? false }
        set { updaterController?.updater.automaticallyChecksForUpdates = newValue }
    }
}
