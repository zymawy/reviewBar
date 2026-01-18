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
            MenuBarContentView()
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
        
        // Onboarding Window (only shown on first run)
        WindowGroup("Welcome to ReviewBar", id: "onboarding") {
            OnboardingView()
                .environmentObject(appDelegate.settingsStore)
                .environmentObject(appDelegate.reviewStore)
                .frame(width: 600, height: 450)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}

// MARK: - Menu Bar Content View

struct MenuBarContentView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var reviewStore: ReviewStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                Text("ReviewBar")
                    .font(.headline)
                Spacer()
                if reviewStore.isReviewing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Pending Reviews Section
            if reviewStore.pendingReviews.isEmpty {
                Text("No pending reviews")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(reviewStore.pendingReviews.prefix(5)) { request in
                    PendingReviewRow(request: request)
                }
                
                if reviewStore.pendingReviews.count > 5 {
                    Text("+ \(reviewStore.pendingReviews.count - 5) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
            }
            
            Divider()
            
            // Recent Results
            if !reviewStore.recentResults.isEmpty {
                Text("Recent Reviews")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                
                ForEach(reviewStore.recentResults.prefix(3)) { result in
                    RecentResultRow(result: result)
                }
                
                Divider()
            }
            
            // Actions
            Button("Dashboard...") {
                NSApp.sendAction(#selector(AppDelegate.showDashboard), to: nil, from: nil)
            }
            .keyboardShortcut("d", modifiers: .command)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            Button("Refresh") {
                Task {
                    await reviewStore.refresh()
                }
            }
            .keyboardShortcut("r", modifiers: .command)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            Divider()
            
            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",", modifiers: .command)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            Button("Quit ReviewBar") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .frame(width: 280)
    }
}

// MARK: - Row Views

struct PendingReviewRow: View {
    let request: ReviewRequest
    
    var body: some View {
        Button {
            // Start review
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.title)
                        .lineLimit(1)
                        .font(.system(size: 12, weight: .medium))
                    
                    HStack(spacing: 4) {
                        Text(request.repository.fullName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("#\(request.number)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

struct RecentResultRow: View {
    let result: ReviewResult
    
    var body: some View {
        Button {
            // Show result modal
        } label: {
            HStack {
                // Recommendation indicator
                Circle()
                    .fill(result.recommendation.color)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.pullRequest.title)
                        .lineLimit(1)
                        .font(.system(size: 11))
                    
                    HStack(spacing: 4) {
                        Text("\(result.issues.count) issues")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if let time = result.analyzedAt.relativeDescription {
                            Text("• \(time)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    MenuBarContentView()
        .environmentObject(SettingsStore())
        .environmentObject(ReviewStore())
}
