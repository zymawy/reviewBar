import AppKit
import SwiftUI
import UserNotifications
import ReviewBarCore

/// AppDelegate handles app lifecycle, status item management, and system integration
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Stores
    
    let settingsStore = SettingsStore()
    let reviewStore = ReviewStore()
    
    // MARK: - Controllers
    
    private var statusItemController: StatusItemController?
    private var dashboardWindow: NSWindow?
    private var reviewModalWindow: NSWindow?
    
    // MARK: - Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)
        
        // 1. Configure Stores
        // We do this first so UI has data
        configureStores()
        
        // 2. Setup Status Item (Menu Bar Icon)
        statusItemController = StatusItemController(
            settingsStore: settingsStore,
            reviewStore: reviewStore
        )
        
        // 3. Start Polling (if enabled)
        if settingsStore.pollingEnabled {
            startPollingTimer()
        }
        
        // 4. Register for Notifications
        registerNotifications()
        
        print("ReviewBar launched successfully")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up
        statusItemController = nil
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running even when all windows closed (menu bar app)
        false
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() async {
        configureStores()
        
        guard settingsStore.hasValidConfiguration else {
            print("ReviewBar: No valid configuration, skipping monitoring")
            return
        }
        
        // Initial fetch
        await reviewStore.refresh()
        
        // Set up polling if enabled
        if settingsStore.pollingEnabled {
            startPollingTimer()
        }
    }
    
    private func configureStores() {
        // 1. Git Providers
        var gitProviders: [any GitProvider] = []
        
        if settingsStore.enabledProviders.contains(.gitHub),
           let token = settingsStore.gitHubToken, !token.isEmpty {
            let github = GitHubProvider(token: token)
            gitProviders.append(github)
        }
        
        if settingsStore.enabledProviders.contains(.gitLab),
           let token = settingsStore.gitLabToken, !token.isEmpty {
            // let gitlab = GitLabProvider(token: token)
            // gitProviders.append(gitlab)
        }
        
        // 2. LLM Provider
        let llmProvider: any LLMProvider
        let apiKey = settingsStore.llmAPIKey ?? ""
        
        switch settingsStore.llmProvider {
        case .claude:
            llmProvider = ClaudeProvider(apiKey: apiKey)
        case .openAI:
            llmProvider = OpenAIProvider(apiKey: apiKey)
        case .gemini:
            // Placeholder for Gemini API (use OpenAI-compatible endpoint)
            llmProvider = OpenAIProvider(apiKey: apiKey) 
        case .ollama:
            guard let ollamaURL = URL(string: "http://localhost:11434") else {
                llmProvider = ClaudeProvider(apiKey: "")
                break
            }
            llmProvider = OllamaProvider(baseURL: ollamaURL)
        // CLI-based providers
        case .claudeCode:
            llmProvider = CLILLMProvider(tool: .claudeCode)
        case .geminiCLI:
            llmProvider = CLILLMProvider(tool: .geminiCLI)
        case .copilotCLI:
            llmProvider = CLILLMProvider(tool: .copilotCLI)
        }
        
        // 3. Skills
        // Install default skills
        if let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let skillsDir = appSupportDir.appendingPathComponent("ReviewBar/skills")
            try? DefaultSkills.install(to: skillsDir)
        }
        
        let mcpBridge = MCPBridge()
        
        // 4. Review Analyzer
        let analyzer = ReviewAnalyzer(llmProvider: llmProvider, mcpBridge: mcpBridge)
        
        // 5. Configure Store
        reviewStore.configure(
            gitProviders: gitProviders,
            reviewAnalyzer: analyzer,
            useCLI: settingsStore.llmProvider.isCLI
        )
        
        print("ReviewBar configured with: \(gitProviders.count) providers, \(settingsStore.llmProvider.displayName)")
    }
    
    private var pollingTask: Task<Void, Never>?
    
    private func startPollingTimer() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(settingsStore.refreshInterval))
                guard !Task.isCancelled else { break }
                await reviewStore.refresh()
            }
        }
    }
    
    // MARK: - Notifications
    
    private func registerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: .settingsDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReviewCompleted(_:)),
            name: .reviewDidComplete,
            object: nil
        )
    }
    
    @objc private func handleSettingsChanged() {
        // Reconfigure services
        configureStores()
        
        // Restart monitoring with new settings
        pollingTask?.cancel()
        if settingsStore.pollingEnabled {
            startPollingTimer()
        }
    }
    
    @objc private func handleReviewCompleted(_ notification: Notification) {
        guard let result = notification.userInfo?["result"] as? ReviewResult else { return }
        
        // Show notification (Native)
        showReviewNotification(result)
        
        // Send Webhook (Slack/Discord)
        if let webhookURL = settingsStore.slackWebhookURL {
            Task {
                await sendWebhook(result, to: webhookURL)
            }
        }
        
        // Open modal if configured
        if settingsStore.showModalOnComplete {
            showReviewModal(result)
        }
    }
    
    private func sendWebhook(_ result: ReviewResult, to url: URL) async {
        let text = """
        Review Complete for *\(result.pullRequest.title)*
        Result: \(result.recommendation.emoji) *\(result.recommendation.displayName)*
        Issues: \(result.issues.count) | Confidence: \(Int(result.confidence * 100))%
        \(result.summary)
        
        <\(result.pullRequest.url.absoluteString)|View Pull Request>
        """
        
        let payload = ["text": text]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("Webhook failed with status: \(httpResponse.statusCode)")
            }
        } catch {
            print("Webhook failed: \(error)")
        }
    }
    
    // MARK: - Windows
    
    @objc func showDashboard() {
        if dashboardWindow == nil {
            let contentView = DashboardView()
                .environmentObject(settingsStore)
                .environmentObject(reviewStore)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "ReviewBar Dashboard"
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            window.setFrameAutosaveName("Dashboard")
            dashboardWindow = window
        }
        
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showReviewModal(_ result: ReviewResult) {
        let contentView = ReviewModalView(result: result)
            .environmentObject(settingsStore)
            .environmentObject(reviewStore)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Review: \(result.pullRequest.title)"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        
        reviewModalWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Notifications (macOS)
    
    private func showReviewNotification(_ result: ReviewResult) {
        // UNUserNotificationCenter crashes when running from CLI without proper app bundle
        // Check if we have a valid bundle before attempting to show notification
        guard Bundle.main.bundleIdentifier != nil else {
            print("Skipping notification: Running without app bundle")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Review Complete"
        content.subtitle = result.pullRequest.title
        content.body = "\(result.issues.count) issues found • \(result.recommendation.displayName)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error)")
            }
        }
    }
}
