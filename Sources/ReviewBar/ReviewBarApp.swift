import SwiftUI
import ReviewBarCore

/// Main app entry point for ReviewBar
/// Uses MenuBarExtra for menu bar presence without Dock icon
@main
struct ReviewBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        // Settings window
        Settings {
            PreferencesView()
                .environmentObject(appDelegate.settingsStore)
                .environmentObject(appDelegate.reviewStore)
        }
        
        // Menu bar presence (macOS 13+)
        MenuBarExtra {
            MenuPopoverView(
                onShowDashboard: { NSApp.sendAction(#selector(AppDelegate.showDashboard), to: nil, from: nil) },
                onShowSettings: { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) },
                onQuit: { NSApp.terminate(nil) }
            )
            .environmentObject(appDelegate.settingsStore)
            .environmentObject(appDelegate.reviewStore)
            .onAppear {
                // Check first run on menu bar appearance (app launch)
                if appDelegate.settingsStore.isFirstRun {
                    openWindow(id: "onboarding")
                }
            }
        } label: {
            // Custom icon rendering handled by StatusItemController for more control
            Image(systemName: "checkmark.circle")
        }
        .menuBarExtraStyle(.window)
        
        // Command Palette Window
        WindowGroup("Command Palette", id: "command-palette") {
            CommandPaletteView()
                .environmentObject(appDelegate.settingsStore)
                .environmentObject(appDelegate.reviewStore)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        
        // Onboarding Window (only shown on first run)
        WindowGroup("Welcome to ReviewBar", id: "onboarding") {
            OnboardingView()
                .environmentObject(appDelegate.settingsStore)
                .environmentObject(appDelegate.reviewStore)
                .frame(width: 600, height: 450)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    UpdateController.shared.checkForUpdates()
                }
                .disabled(!UpdateController.shared.canCheckForUpdates)
            }
            
            CommandMenu("Review") {
                Button("Dashboard") {
                    NSApp.sendAction(#selector(AppDelegate.showDashboard), to: nil, from: nil)
                }
                .keyboardShortcut("d", modifiers: .command)
                
                Button("Refresh") {
                    Task { await appDelegate.reviewStore.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Divider()
                
                Button("Command Palette...") {
                    openWindow(id: "command-palette")
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}


// MARK: - Preview

#Preview {
    MenuPopoverView(
        onShowDashboard: {},
        onShowSettings: {},
        onQuit: {}
    )
    .environmentObject(SettingsStore())
    .environmentObject(ReviewStore())
}
