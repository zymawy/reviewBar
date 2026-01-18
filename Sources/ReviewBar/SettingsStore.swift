import Foundation
import Combine
import ServiceManagement

/// Persistent settings store using UserDefaults with ObservableObject for SwiftUI reactivity
@MainActor
public final class SettingsStore: ObservableObject {
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let refreshInterval = "refreshInterval"
        static let pollingEnabled = "pollingEnabled"
        static let showInDock = "showInDock"
        static let showModalOnComplete = "showModalOnComplete"
        static let isFirstRun = "isFirstRun"
        
        static let enabledProviders = "enabledProviders"
        static let gitHubToken = "gitHubToken"
        static let gitLabToken = "gitLabToken"
        
        static let llmProvider = "llmProvider"
        static let llmAPIKey = "llmAPIKey"
        static let llmModel = "llmModel"
        
        static let notifyOnComplete = "notifyOnComplete"
        static let slackWebhookURL = "slackWebhookURL"
        static let discordWebhookURL = "discordWebhookURL"
        
        static let autoReviewOnAssign = "autoReviewOnAssign"
        static let defaultProfileID = "defaultProfileID"
        
        static let watchedRepositories = "watchedRepositories"
    }
    
    private let defaults: UserDefaults
    
    // MARK: - Init
    
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadSettings()
    }
    
    // MARK: - General Settings
    


// ...

    @Published public var launchAtLogin: Bool = false {
        didSet {
            // Avoid infinite recursion if updated from loadSettings
            if oldValue != launchAtLogin {
                defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
                updateLaunchAtLogin()
                notifyChange()
            }
        }
    }
    
    @Published public var isFirstRun: Bool = true {
        didSet {
            defaults.set(isFirstRun, forKey: Keys.isFirstRun)
            notifyChange()
        }
    }
    
    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
    
    @Published public var refreshInterval: TimeInterval = 300 { // 5 minutes default
        didSet {
            defaults.set(refreshInterval, forKey: Keys.refreshInterval)
            notifyChange()
        }
    }
    
    @Published public var pollingEnabled: Bool = true {
        didSet {
            defaults.set(pollingEnabled, forKey: Keys.pollingEnabled)
            notifyChange()
        }
    }
    
    public var showInDock: Bool = false {
        didSet {
            defaults.set(showInDock, forKey: Keys.showInDock)
            notifyChange()
        }
    }
    
    public var showModalOnComplete: Bool = true {
        didSet {
            defaults.set(showModalOnComplete, forKey: Keys.showModalOnComplete)
            notifyChange()
        }
    }
    
    // MARK: - Provider Settings
    
    public var enabledProviders: Set<GitProviderType> = [.gitHub] {
        didSet {
            let rawValues = enabledProviders.map { $0.rawValue }
            defaults.set(rawValues, forKey: Keys.enabledProviders)
            notifyChange()
        }
    }
    
    // Note: Tokens should be stored in Keychain in production
    public var gitHubToken: String? {
        didSet {
            defaults.set(gitHubToken, forKey: Keys.gitHubToken)
            notifyChange()
        }
    }
    
    public var gitLabToken: String? {
        didSet {
            defaults.set(gitLabToken, forKey: Keys.gitLabToken)
            notifyChange()
        }
    }
    
    // MARK: - LLM Settings
    
    public var llmProvider: LLMProviderType = .claude {
        didSet {
            defaults.set(llmProvider.rawValue, forKey: Keys.llmProvider)
            notifyChange()
        }
    }
    
    public var llmModel: String = "claude-3-5-sonnet-20241022" {
        didSet {
            defaults.set(llmModel, forKey: Keys.llmModel)
            notifyChange()
        }
    }
    
    @Published public var llmAPIKey: String? {
        didSet {
            defaults.set(llmAPIKey, forKey: Keys.llmAPIKey)
            notifyChange()
        }
    }
    
    // MARK: - Notification Settings
    
    public var notifyOnComplete: Bool = true {
        didSet {
            defaults.set(notifyOnComplete, forKey: Keys.notifyOnComplete)
            notifyChange()
        }
    }
    
    public var slackWebhookURL: URL? {
        didSet {
            defaults.set(slackWebhookURL?.absoluteString, forKey: Keys.slackWebhookURL)
            notifyChange()
        }
    }
    
    public var discordWebhookURL: URL? {
        didSet {
            defaults.set(discordWebhookURL?.absoluteString, forKey: Keys.discordWebhookURL)
            notifyChange()
        }
    }
    
    // MARK: - Review Settings
    
    public var autoReviewOnAssign: Bool = false {
        didSet {
            defaults.set(autoReviewOnAssign, forKey: Keys.autoReviewOnAssign)
            notifyChange()
        }
    }
    
    public var defaultProfileID: UUID? {
        didSet {
            defaults.set(defaultProfileID?.uuidString, forKey: Keys.defaultProfileID)
            notifyChange()
        }
    }
    
    public var watchedRepositories: [String] = [] {
        didSet {
            defaults.set(watchedRepositories, forKey: Keys.watchedRepositories)
            notifyChange()
        }
    }
    
    // MARK: - Computed Properties
    
    public var hasValidConfiguration: Bool {
        // At least one provider with token
        if enabledProviders.contains(.gitHub) && gitHubToken != nil {
            return true
        }
        if enabledProviders.contains(.gitLab) && gitLabToken != nil {
            return true
        }
        return false
    }
    
    public var refreshIntervalOptions: [(String, TimeInterval)] {
        [
            ("1 minute", 60),
            ("2 minutes", 120),
            ("5 minutes", 300),
            ("15 minutes", 900),
            ("30 minutes", 1800),
            ("Manual only", 0)
        ]
    }
    
    // MARK: - Load/Save
    
    private func loadSettings() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        refreshInterval = defaults.double(forKey: Keys.refreshInterval).nonZeroOr(300)
        pollingEnabled = defaults.object(forKey: Keys.pollingEnabled) as? Bool ?? true
        showInDock = defaults.bool(forKey: Keys.showInDock)
        showModalOnComplete = defaults.object(forKey: Keys.showModalOnComplete) as? Bool ?? true
        isFirstRun = defaults.object(forKey: Keys.isFirstRun) as? Bool ?? true
        
        if let providerRaws = defaults.stringArray(forKey: Keys.enabledProviders) {
            enabledProviders = Set(providerRaws.compactMap { GitProviderType(rawValue: $0) })
        }
        
        gitHubToken = defaults.string(forKey: Keys.gitHubToken)
        gitLabToken = defaults.string(forKey: Keys.gitLabToken)
        
        if let providerRaw = defaults.string(forKey: Keys.llmProvider),
           let provider = LLMProviderType(rawValue: providerRaw) {
            llmProvider = provider
        }
        llmModel = defaults.string(forKey: Keys.llmModel) ?? "claude-3-5-sonnet-20241022"
        llmAPIKey = defaults.string(forKey: Keys.llmAPIKey)
        
        notifyOnComplete = defaults.object(forKey: Keys.notifyOnComplete) as? Bool ?? true
        if let slackURLString = defaults.string(forKey: Keys.slackWebhookURL) {
            slackWebhookURL = URL(string: slackURLString)
        }
        if let discordURLString = defaults.string(forKey: Keys.discordWebhookURL) {
            discordWebhookURL = URL(string: discordURLString)
        }
        
        autoReviewOnAssign = defaults.bool(forKey: Keys.autoReviewOnAssign)
        if let profileIDString = defaults.string(forKey: Keys.defaultProfileID) {
            defaultProfileID = UUID(uuidString: profileIDString)
        }
        
        watchedRepositories = defaults.stringArray(forKey: Keys.watchedRepositories) ?? []
    }
    
    private func notifyChange() {
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
}

// MARK: - Enums

public enum GitProviderType: String, Codable, CaseIterable, Sendable {
    case gitHub = "github"
    case gitLab = "gitlab"
    case bitbucket = "bitbucket"
    
    public var displayName: String {
        switch self {
        case .gitHub: return "GitHub"
        case .gitLab: return "GitLab"
        case .bitbucket: return "Bitbucket"
        }
    }
    
    public var iconName: String {
        switch self {
        case .gitHub: return "github.logo"
        case .gitLab: return "gitlab.logo"
        case .bitbucket: return "bitbucket.logo"
        }
    }
}

public enum LLMProviderType: String, Codable, CaseIterable, Sendable {
    case claude = "claude"
    case openAI = "openai"
    case gemini = "gemini"
    case ollama = "ollama"
    // CLI-based providers (no API key required)
    case claudeCode = "claude-code"
    case geminiCLI = "gemini-cli"
    case copilotCLI = "copilot-cli"
    
    public var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .openAI: return "OpenAI"
        case .gemini: return "Gemini"
        case .ollama: return "Ollama (Local)"
        case .claudeCode: return "Claude Code (CLI)"
        case .geminiCLI: return "Gemini (CLI)"
        case .copilotCLI: return "GitHub Copilot (CLI)"
        }
    }
    
    public var defaultModel: String {
        switch self {
        case .claude: return "claude-3-5-sonnet-20241022"
        case .openAI: return "gpt-4o"
        case .gemini: return "gemini-2.0-flash"
        case .ollama: return "codellama"
        case .claudeCode, .geminiCLI, .copilotCLI: return "default"
        }
    }
    
    public var availableModels: [String] {
        switch self {
        case .claude:
            return [
                "claude-3-5-sonnet-20241022",
                "claude-3-5-haiku-20241022",
                "claude-3-opus-20240229"
            ]
        case .openAI:
            return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "o1", "o1-mini"]
        case .gemini:
            return ["gemini-2.0-flash", "gemini-2.0-flash-thinking", "gemini-1.5-pro"]
        case .ollama:
            return ["codellama", "deepseek-coder", "llama3.1"]
        case .claudeCode, .geminiCLI, .copilotCLI:
            return ["default"]
        }
    }
    
    /// Whether this provider requires an API key
    public var requiresAPIKey: Bool {
        switch self {
        case .claude, .openAI, .gemini:
            return true
        case .ollama, .claudeCode, .geminiCLI, .copilotCLI:
            return false
        }
    }
    
    /// Whether this is a CLI-based provider
    public var isCLI: Bool {
        switch self {
        case .claudeCode, .geminiCLI, .copilotCLI:
            return true
        default:
            return false
        }
    }
}

// MARK: - Extensions

extension Double {
    func nonZeroOr(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}

extension Notification.Name {
    public static let settingsDidChange = Notification.Name("ReviewBarSettingsDidChange")
}
