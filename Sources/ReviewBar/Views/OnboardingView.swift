import SwiftUI
import ReviewBarCore

struct OnboardingView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Image/Animation could go here
            
            // Content
            Group {
                switch currentStep {
                case 0:
                    WelcomeStep(onNext: nextStep)
                case 1:
                    GitHubSetupStep(onNext: nextStep)
                case 2:
                    AISetupStep(onNext: nextStep)
                case 3:
                    CompletionStep(onFinish: finishOnboarding)
                default:
                    EmptyView()
                }
            }
            .transition(.push(from: .trailing))
            .animation(.easeInOut, value: currentStep)
            
            // Footer Navigation
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        if currentStep > 0 {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.borderless)
                }
                
                Spacer()
                
                // Indicators
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                if currentStep < 3 {
                    Button("Skip") {
                        currentStep = 3
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                } else {
                    Spacer().frame(width: 30) // Balance spacing
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
        }
        .frame(width: 600, height: 450)
        .background(EffectView(material: .sidebar, blendingMode: .behindWindow))
    }
    
    private func nextStep() {
        if currentStep < 3 {
            currentStep += 1
        }
    }
    
    private func finishOnboarding() {
        settingsStore.isFirstRun = false
        dismiss()
    }
}

// MARK: - Steps

struct WelcomeStep: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            
            VStack(spacing: 12) {
                Text("Welcome to ReviewBar")
                    .font(.largeTitle.weight(.bold))
                
                Text("Your AI-powered production code review assistant.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "brain.head.profile", title: "AI Analysis", description: "Catch bugs and get suggestions using Claude, Gemini, or OpenAI.")
                FeatureRow(icon: "terminal", title: "CLI Integration", description: "Use your existing CLI tools without needing API keys.")
                FeatureRow(icon: "bell.badge", title: "Smart Notifications", description: "Get notified when your reviews are ready.")
            }
            .padding(.vertical)
            
            Spacer()
            
            Button("Get Started") {
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
    }
}

struct GitHubSetupStep: View {
    let onNext: () -> Void
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var token = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Connect GitHub")
                .font(.title2.weight(.bold))
            
            Text("ReviewBar needs a Personal Access Token (PAT) to fetch your pull requests and post reviews.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Personal Access Token")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("ghp_...", text: $token)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: 300)
            
            HStack(spacing: 12) {
                Link("Generate Token", destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:user")!)
                
                Button("Paste from Clipboard") {
                   if let clipboard = NSPasteboard.general.string(forType: .string) {
                       token = clipboard
                   }
                }
            }
            .font(.caption)
            
            Spacer()
            
            Button("Continue") {
                settingsStore.gitHubToken = token
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(token.isEmpty)
        }
        .padding(40)
    }
}

struct AISetupStep: View {
    let onNext: () -> Void
    @EnvironmentObject var settings: SettingsStore
    
    // Copy logic from PreferencesView
    @State private var detectedCLITools: [LLMProviderType] = []
    @State private var isDetecting = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Choose Your AI")
                .font(.title2.weight(.bold))
            
            if isDetecting {
                ProgressView("Scanning for installed tools...")
            } else if !detectedCLITools.isEmpty {
                VStack(spacing: 16) {
                    Text("We found these existing tools installed:")
                        .foregroundColor(.secondary)
                    
                    ForEach(detectedCLITools, id: \.self) { provider in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(provider.displayName)
                            Spacer()
                            Button("Use") {
                                settings.llmProvider = provider
                                settings.llmModel = provider.defaultModel
                                onNext()
                            }
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .frame(maxWidth: 400)
            }
            
            if !detectedCLITools.isEmpty {
                Divider().frame(width: 200)
            }
            
            VStack(spacing: 12) {
                Text("Or configure manually later:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Ensure I have an API Key") {
                    onNext()
                }
            }
            
            Spacer()
        }
        .padding(40)
        .task {
            await detectCLITools()
        }
    }
    
    // Reuse logic from PreferencesView (ideally refactor to shared service)
    private func detectCLITools() async {
        isDetecting = true
        defer { isDetecting = false }
        
        var detected: [LLMProviderType] = []
        if await checkCLITool("claude") { detected.append(.claudeCode) }
        if await checkCLITool("gemini") { detected.append(.geminiCLI) }
        if await checkGHCopilot() { detected.append(.copilotCLI) }
        
        await MainActor.run { detectedCLITools = detected }
    }
    
    private let commonPaths = [
        "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin",
        NSString(string: "~/.local/bin").expandingTildeInPath
    ]
    
    private func checkCLITool(_ command: String) async -> Bool {
        for basePath in commonPaths {
            if FileManager.default.fileExists(atPath: "\(basePath)/\(command)") { return true }
        }
        return false
    }
    
    private func checkGHCopilot() async -> Bool {
        for basePath in commonPaths {
            if FileManager.default.fileExists(atPath: "\(basePath)/gh") { return true } // Simplified check
        }
        return false
    }
}

struct CompletionStep: View {
    let onFinish: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "party.popper.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.yellow)
            
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.largeTitle.weight(.bold))
                
                Text("ReviewBar is now running in your menu bar.")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Text("Click the checkmark icon in the menu bar to see your reviews.")
                .font(.callout)
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            
            Spacer()
            
            Button("Start Using ReviewBar") {
                onFinish()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
             .keyboardShortcut(.defaultAction)
        }
        .padding(40)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// Background blur effect
struct EffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
