import Foundation

/// Supported CLI-based AI coding tools
public enum CLITool: String, CaseIterable, Sendable {
    case claudeCode = "claude"
    case geminiCLI = "gemini"
    case copilotCLI = "gh"
    
    /// Display name for the UI
    public var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code (CLI)"
        case .geminiCLI: return "Gemini (CLI)"
        case .copilotCLI: return "GitHub Copilot (CLI)"
        }
    }
    
    /// The command to invoke
    public var command: String {
        rawValue
    }
    
    /// Arguments to pass for a prompt
    public func arguments(for prompt: String) -> [String] {
        switch self {
        case .claudeCode:
            // Claude Code CLI: claude -p "prompt" --output-format json
            // Note: Claude Code may have internal issues in some versions
            return ["-p", prompt, "--output-format", "json"]
        case .geminiCLI:
            // Gemini CLI: gemini "prompt" --yolo (auto-approve actions)
            // Uses positional argument for prompt
            return [prompt, "--yolo"]
        case .copilotCLI:
            // GitHub Copilot: gh copilot suggest "prompt"
            return ["copilot", "suggest", prompt]
        }
    }
    
    /// Check if the CLI tool is installed (exists in PATH)
    public static func isInstalled(_ tool: CLITool) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [tool.command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    /// Check if the tool is authenticated (tool-specific checks)
    public static func isAuthenticated(_ tool: CLITool) async -> Bool {
        switch tool {
        case .claudeCode:
            // Check if ~/.claude directory exists with credentials
            let claudeDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude")
            return FileManager.default.fileExists(atPath: claudeDir.path)
            
        case .geminiCLI:
            // Check for gcloud auth or gemini config
            let configPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/gemini")
            return FileManager.default.fileExists(atPath: configPath.path)
            
        case .copilotCLI:
            // Check if gh is logged in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["gh", "auth", "status"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }
    }
    
    /// Detect all installed and authenticated CLI tools
    public static func detectAvailableTools() async -> [CLITool] {
        var available: [CLITool] = []
        
        for tool in CLITool.allCases {
            if isInstalled(tool) {
                let authenticated = await isAuthenticated(tool)
                if authenticated {
                    available.append(tool)
                }
            }
        }
        
        return available
    }
}
