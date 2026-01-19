import SwiftUI
import ReviewBarCore

/// Main preferences/settings view
struct PreferencesView: View {
    @State private var selectedPane: PreferencesPane? = .general
    
    var body: some View {
        NavigationSplitView {
            List(PreferencesPane.allCases, selection: $selectedPane) { pane in
                Label(pane.title, systemImage: pane.icon)
                    .tag(pane)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            if let pane = selectedPane {
                pane.view
            } else {
                Text("Select a category")
            }
        }
        .frame(minWidth: 650, minHeight: 450)
    }
}

enum PreferencesPane: String, CaseIterable, Identifiable {
    case general
    case providers
    case llm
    case skills
    case profiles
    case notifications
    case advanced
    
    case about
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .general: return "General"
        case .providers: return "Git Providers"
        case .llm: return "LLM"
        case .skills: return "Skills"
        case .profiles: return "Profiles"
        case .notifications: return "Notifications"
        case .advanced: return "Advanced"
        case .about: return "About"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .providers: return "arrow.triangle.branch"
        case .llm: return "cpu"
        case .skills: return "wand.and.stars"
        case .profiles: return "person.2"
        case .notifications: return "bell"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }
    
    @ViewBuilder
    var view: some View {
        switch self {
        case .general: GeneralPane()
        case .providers: ProvidersPane()
        case .llm: LLMPane()
        case .skills: SkillsPane()
        case .profiles: ProfilesPane()
        case .notifications: NotificationsPane()
        case .advanced: AdvancedPane()
        case .about: AboutPane()
        }
    }
}

// MARK: - General Pane

struct GeneralPane: View {
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                ))
                
                Toggle("Show icon in Dock", isOn: Binding(
                    get: { settings.showInDock },
                    set: { settings.showInDock = $0 }
                ))
                .help("Usually disabled for menu bar apps")
            }
            
            Section("Refresh") {
                Picker("Check for new reviews", selection: Binding(
                    get: { settings.refreshInterval },
                    set: { settings.refreshInterval = $0 }
                )) {
                    ForEach(settings.refreshIntervalOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }
                
                Toggle("Enable polling", isOn: Binding(
                    get: { settings.pollingEnabled },
                    set: { settings.pollingEnabled = $0 }
                ))
                .help("Disable to only refresh manually")
            }
            
            Section("Review Behavior") {
                Toggle("Automatically review when assigned", isOn: Binding(
                    get: { settings.autoReviewOnAssign },
                    set: { settings.autoReviewOnAssign = $0 }
                ))
                .help("Start AI review immediately when you're requested as reviewer")
                
                Toggle("Show results modal when complete", isOn: Binding(
                    get: { settings.showModalOnComplete },
                    set: { settings.showModalOnComplete = $0 }
                ))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

// MARK: - Providers Pane

struct ProvidersPane: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var gitHubToken = ""
    @State private var gitLabToken = ""
    @State private var showGitHubToken = false
    @State private var showGitLabToken = false
    
    var body: some View {
        Form {
            Section("GitHub") {
                Toggle("Enable GitHub", isOn: Binding(
                    get: { settings.enabledProviders.contains(.gitHub) },
                    set: { enabled in
                        if enabled {
                            settings.enabledProviders.insert(.gitHub)
                        } else {
                            settings.enabledProviders.remove(.gitHub)
                        }
                    }
                ))
                
                if settings.enabledProviders.contains(.gitHub) {
                    HStack {
                        if showGitHubToken {
                            TextField("Personal Access Token", text: $gitHubToken)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Personal Access Token", text: $gitHubToken)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button {
                            showGitHubToken.toggle()
                        } label: {
                            Image(systemName: showGitHubToken ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                    .onAppear {
                        gitHubToken = settings.gitHubToken ?? ""
                    }
                    .onChange(of: gitHubToken) { _, newValue in
                        settings.gitHubToken = newValue.isEmpty ? nil : newValue
                    }
                    
                    if let url = URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:user") {
                        Link("Create a token on GitHub →", destination: url)
                            .font(.caption)
                    }
                }
            }
            
            Section("GitLab") {
                Toggle("Enable GitLab", isOn: Binding(
                    get: { settings.enabledProviders.contains(.gitLab) },
                    set: { enabled in
                        if enabled {
                            settings.enabledProviders.insert(.gitLab)
                        } else {
                            settings.enabledProviders.remove(.gitLab)
                        }
                    }
                ))
                
                if settings.enabledProviders.contains(.gitLab) {
                    HStack {
                        if showGitLabToken {
                            TextField("Personal Access Token", text: $gitLabToken)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Personal Access Token", text: $gitLabToken)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button {
                            showGitLabToken.toggle()
                        } label: {
                            Image(systemName: showGitLabToken ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                    .onAppear {
                        gitLabToken = settings.gitLabToken ?? ""
                    }
                    .onChange(of: gitLabToken) { _, newValue in
                        settings.gitLabToken = newValue.isEmpty ? nil : newValue
                    }
                }
            }
            
            Section("Watched Repositories") {
                Text("Add repositories to watch for review requests")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // TODO: Repository list editor
                Text("Coming soon...")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Git Providers")
    }
}

// MARK: - LLM Pane

struct LLMPane: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var apiKey = ""
    @State private var showAPIKey = false
    @State private var detectedCLITools: [LLMProviderType] = []
    @State private var isDetecting = false
    
    var body: some View {
        Form {
            // Detected CLI Tools Section
            Section("Detected CLI Tools") {
                if isDetecting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Scanning for installed tools...")
                            .foregroundColor(.secondary)
                    }
                } else if detectedCLITools.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("No CLI tools detected")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Install Claude Code, Gemini CLI, or GitHub Copilot to use without an API key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(detectedCLITools, id: \.self) { provider in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(provider.displayName)
                            Spacer()
                            if settings.llmProvider == provider {
                                Text("Active")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            } else {
                                Button("Use") {
                                    settings.llmProvider = provider
                                    settings.llmModel = provider.defaultModel
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                
                Button("Refresh Detection") {
                    Task {
                        await detectCLITools()
                    }
                }
            }
            
            Section("Provider") {
                Picker("LLM Provider", selection: Binding(
                    get: { settings.llmProvider },
                    set: { settings.llmProvider = $0 }
                )) {
                    // API-based providers
                    Text("Claude").tag(LLMProviderType.claude)
                    Text("OpenAI").tag(LLMProviderType.openAI)
                    Text("Gemini").tag(LLMProviderType.gemini)
                    Text("Ollama (Local)").tag(LLMProviderType.ollama)
                    
                    Divider()
                    
                    // CLI-based providers (only show if detected)
                    ForEach(detectedCLITools, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                
                if !settings.llmProvider.isCLI {
                    Picker("Model", selection: Binding(
                        get: { settings.llmModel },
                        set: { settings.llmModel = $0 }
                    )) {
                        ForEach(settings.llmProvider.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
            }
            
            // API Key Section (only for API-based providers)
            if settings.llmProvider.requiresAPIKey {
                Section("API Key") {
                    HStack {
                        if showAPIKey {
                            TextField("API Key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("API Key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    apiKeyHelpLink
                }
                .onAppear {
                    apiKey = settings.llmAPIKey ?? ""
                }
                .onChange(of: apiKey) { _, newValue in
                    settings.llmAPIKey = newValue.isEmpty ? nil : newValue
                }
            } else if settings.llmProvider == .ollama {
                Section("Local Setup") {
                    Text("Ollama runs locally - no API key needed")
                        .foregroundColor(.secondary)
                    
                    if let ollamaURL = URL(string: "https://ollama.ai") {
                        Link("Install Ollama →", destination: ollamaURL)
                            .font(.caption)
                    }
                }
            } else if settings.llmProvider.isCLI {
                Section("CLI Authentication") {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("Using your existing \(settings.llmProvider.displayName) authentication")
                    }
                    
                    Text("No API key required - the CLI uses your logged-in account")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("LLM Configuration")
        .task {
            await detectCLITools()
        }
    }
    
    private func detectCLITools() async {
        isDetecting = true
        defer { isDetecting = false }
        
        var detected: [LLMProviderType] = []
        
        // Check Claude Code
        if await checkCLITool("claude", authCheck: "~/.claude") {
            detected.append(.claudeCode)
        }
        
        // Check Gemini CLI
        if await checkCLITool("gemini", authCheck: "~/.config/gemini") {
            detected.append(.geminiCLI)
        }
        
        // Check GitHub Copilot CLI (via gh)
        if await checkGHCopilot() {
            detected.append(.copilotCLI)
        }
        
        await MainActor.run {
            detectedCLITools = detected
        }
    }
    
    /// Common paths where CLI tools might be installed (GUI apps have limited PATH)
    private let commonPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        NSString(string: "~/.local/bin").expandingTildeInPath
    ]
    
    private func checkCLITool(_ command: String, authCheck: String) async -> Bool {
        // Check common paths for the CLI tool (GUI apps don't have full PATH)
        var foundPath: String? = nil
        
        for basePath in commonPaths {
            let fullPath = "\(basePath)/\(command)"
            if FileManager.default.fileExists(atPath: fullPath) {
                foundPath = fullPath
                break
            }
        }
        
        guard let foundPath else {
            print("CLI detection: \(command) not found in common paths")
            return false
        }
        print("CLI detection: Found \(command) at \(foundPath)")
        
        // For now, skip auth check - if the binary exists, assume it's usable
        // The actual auth will be verified when the CLI is invoked
        return true
    }
    
    private func checkGHCopilot() async -> Bool {
        // Check if gh exists in common paths
        var ghPath: String? = nil
        
        for basePath in commonPaths {
            let fullPath = "\(basePath)/gh"
            if FileManager.default.fileExists(atPath: fullPath) {
                ghPath = fullPath
                break
            }
        }
        
        guard let path = ghPath else {
            print("CLI detection: gh not found")
            return false
        }
        
        print("CLI detection: Found gh at \(path)")
        
        // Check if gh copilot extension is installed
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["extension", "list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains("copilot")
            }
        } catch {
            print("CLI detection: gh extension list failed: \(error)")
        }
        
        return false
    }
    
    @ViewBuilder
    private var apiKeyHelpLink: some View {
        switch settings.llmProvider {
        case .claude:
            if let url = URL(string: "https://console.anthropic.com/account/keys") {
                Link("Get an Anthropic API key →", destination: url)
                    .font(.caption)
            }
        case .openAI:
            if let url = URL(string: "https://platform.openai.com/api-keys") {
                Link("Get an OpenAI API key →", destination: url)
                    .font(.caption)
            }
        case .gemini:
            if let url = URL(string: "https://makersuite.google.com/app/apikey") {
                Link("Get a Google AI API key →", destination: url)
                    .font(.caption)
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Skills Pane

struct SkillsPane: View {
    @State private var skills: [SkillInfo] = []
    
    var body: some View {
        Form {
            Section("Installed Skills") {
                if skills.isEmpty {
                    Text("No custom skills installed")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(skills) { skill in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(skill.name)
                                    .font(.headline)
                                Text(skill.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: .constant(skill.enabled))
                        }
                    }
                }
            }
            
            Section {
                Button("Open Skills Folder") {
                    guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
                    let url = appSupport.appendingPathComponent("ReviewBar/skills")
                    
                    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(url)
                }
                
                Button("Import Skill...") {
                    // TODO: File picker
                }
            }
            
            Section("About Skills") {
                Text("Skills are YAML files that define custom review rules and prompts. Place them in the skills folder to use them.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let docsURL = URL(string: "https://github.com/reviewbar/docs/skills") {
                    Link("Learn more about creating skills →", destination: docsURL)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Skills")
    }
}

struct SkillInfo: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let enabled: Bool
}

// MARK: - Profiles Pane

struct ProfilesPane: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var selectedProfileID: UUID?
    
    // Sort profiles to keep standard ones first
    var sortedProfiles: [ReviewProfile] {
        settings.allProfiles
    }
    
    var body: some View {
        HSplitView {
            // Profile list
            VStack(spacing: 0) {
                List(sortedProfiles, selection: $selectedProfileID) { profile in
                    HStack {
                        Image(systemName: profile.icon)
                            .foregroundColor(profile.isDefault ? .secondary : .primary)
                        VStack(alignment: .leading) {
                            Text(profile.name)
                                .font(.headline)
                            if profile.isDefault {
                                Text("Built-in")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tag(profile.id)
                }
                .listStyle(.sidebar)
                .frame(minWidth: 180, maxWidth: 200)
                
                Divider()
                
                HStack {
                    Button {
                        let newProfile = ReviewProfile(
                            name: "New Profile",
                            icon: "person.circle",
                            systemPrompt: "You are a code reviewer."
                        )
                        settings.customProfiles.append(newProfile)
                        selectedProfileID = newProfile.id
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Add Profile")
                    
                    Spacer()
                    
                    Button {
                        if let id = selectedProfileID,
                           let index = settings.customProfiles.firstIndex(where: { $0.id == id }) {
                            settings.customProfiles.remove(at: index)
                            selectedProfileID = nil
                        }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedProfileID == nil || sortedProfiles.first(where: { $0.id == selectedProfileID })?.isDefault == true)
                    .help("Remove Profile")
                }
                .padding(8)
            }
            
            // Profile editor
            if let profileID = selectedProfileID,
               let profile = sortedProfiles.first(where: { $0.id == profileID }) {
                
                // If it's a built-in profile, show read-only view
                if profile.isDefault {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Image(systemName: profile.icon)
                                    .font(.system(size: 48))
                                VStack(alignment: .leading) {
                                    Text(profile.name)
                                        .font(.title)
                                    Text("Built-in Profile")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.bottom)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("System Prompt")
                                    .font(.headline)
                                Text(profile.systemPrompt)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            Spacer()
                        }
                        .padding()
                    }
                } else {
                    // Editable view for custom profiles
                    ProfileEditor(
                        profile: Binding(
                            get: { profile },
                            set: { newValue in
                                if let index = settings.customProfiles.firstIndex(where: { $0.id == newValue.id }) {
                                    settings.customProfiles[index] = newValue
                                }
                            }
                        )
                    )
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Select a profile to edit")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Review Profiles")
    }
}

struct ProfileEditor: View {
    @Binding var profile: ReviewProfile
    
    var body: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $profile.name)
                
                HStack {
                    Text("Icon")
                    Spacer()
                    TextField("SF Symbol Name", text: $profile.icon)
                        .frame(width: 150)
                    Image(systemName: profile.icon)
                }
            }
            
            Section("Behavior") {
                VStack(alignment: .leading) {
                    Text("System Prompt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $profile.systemPrompt)
                        .font(.body.monospaced())
                        .frame(minHeight: 150)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Notifications Pane

struct NotificationsPane: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var slackURL = ""
    @State private var discordURL = ""
    
    var body: some View {
        Form {
            Section("macOS Notifications") {
                Toggle("Show notification when review completes", isOn: Binding(
                    get: { settings.notifyOnComplete },
                    set: { settings.notifyOnComplete = $0 }
                ))
            }
            
            Section("Slack") {
                TextField("Webhook URL", text: $slackURL)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        slackURL = settings.slackWebhookURL?.absoluteString ?? ""
                    }
                    .onChange(of: slackURL) { _, newValue in
                        settings.slackWebhookURL = URL(string: newValue)
                    }
                
                Link("How to create a Slack webhook →", destination: URL(string: "https://api.slack.com/messaging/webhooks")!)
                    .font(.caption)
            }
            
            Section("Discord") {
                TextField("Webhook URL", text: $discordURL)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        discordURL = settings.discordWebhookURL?.absoluteString ?? ""
                    }
                    .onChange(of: discordURL) { _, newValue in
                        settings.discordWebhookURL = URL(string: newValue)
                    }
                
                Link("How to create a Discord webhook →", destination: URL(string: "https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks")!)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Notifications")
    }
}

// MARK: - Advanced Pane

struct AdvancedPane: View {
    var body: some View {
        Form {
            Section("Debug") {
                Button("View Logs...") {
                    // TODO: Open log window
                }
                
                Button("Export Diagnostics...") {
                    // TODO: Export debug info
                }
            }
            
            Section("Data") {
                Button("Clear Review Cache") {
                    // TODO: Clear cache
                }
                
                Button("Reset All Settings", role: .destructive) {
                    // TODO: Reset settings
                }
            }
            
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")
                
                Link("View on GitHub", destination: URL(string: "https://github.com/zymawy/reviewbar")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/zymawy/reviewbar/issues")!)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Advanced")
    }
}

// MARK: - About Pane

struct AboutPane: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App Icon
            if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
               let image = NSImage(contentsOfFile: iconPath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
                    .shadow(radius: 10)
            } else {
                // Fallback if icon not loaded in preview
                Image(systemName: "app.dashed")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            
            VStack(spacing: 8) {
                Text("ReviewBar")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Version 1.0.0 (1)")
                    .foregroundColor(.secondary)
                
                Text("May your code always compile and your reviews be swift.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            
            VStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/zymawy/reviewbar")!) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        .frame(width: 200)
                }
                
                Link(destination: URL(string: "https://github.com/zymawy/reviewbar/issues")!) {
                    Label("Report Issue", systemImage: "ant")
                        .frame(width: 200)
                }
                
                Link(destination: URL(string: "mailto:support@reviewbar.app")!) {
                    Label("Contact Support", systemImage: "envelope")
                        .frame(width: 200)
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            
            Spacer()
            
            Divider()
                .frame(width: 300)
            
            VStack(spacing: 8) {
                Button("Check for Updates...") {
                    UpdateController.shared.checkForUpdates()
                }
                .disabled(!UpdateController.shared.canCheckForUpdates)
                
                Text("© 2026 ReviewBar Contributors. MIT License.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("About")
    }
}

// MARK: - Preview

#Preview {
    PreferencesView()
        .environmentObject(SettingsStore())
}
