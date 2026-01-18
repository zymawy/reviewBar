import Foundation

/// LLM Provider that uses CLI tools (Claude Code, Gemini CLI, etc.) as backends
public actor CLILLMProvider: LLMProvider {
    
    public nonisolated let id: String
    public nonisolated let displayName: String
    public nonisolated let supportedModels: [String]
    
    private let tool: CLITool
    private let timeoutSeconds: TimeInterval
    
    public init(tool: CLITool, timeoutSeconds: TimeInterval = 300) {
        self.tool = tool
        self.id = "cli-\(tool.rawValue)"
        self.displayName = tool.displayName
        self.supportedModels = ["default"]
        self.timeoutSeconds = timeoutSeconds
    }
    
    /// Run a review in a cloned repository directory
    /// - Parameters:
    ///   - prompt: The review prompt
    ///   - model: Model name (ignored for CLI tools)
    ///   - workingDirectory: The cloned repo directory
    /// - Returns: The CLI tool's output
    public func complete(prompt: String, model: String, workingDirectory: URL? = nil) async throws -> String {
        // Build the command string
        let command = tool.command
        let args = tool.arguments(for: prompt)
        let fullCommand = ([command] + args).map { escapeShellArg($0) }.joined(separator: " ")
        
        // Use login shell for full environment (node, etc.)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", fullCommand]
        
        // Set working directory if provided
        if let workDir = workingDirectory {
            process.currentDirectoryURL = workDir
        }
        
        // Set up pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        print("CLILLMProvider: Running '\(command)' in \(workingDirectory?.path ?? "current dir")")
        
        // Run with timeout
        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task {
                try await Task.sleep(for: .seconds(timeoutSeconds))
                if process.isRunning {
                    process.terminate()
                }
            }
            
            Task {
                do {
                    try process.run()
                    process.waitUntilExit()
                    timeoutTask.cancel()
                    
                    if process.terminationStatus != 0 {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: LLMError.serverError(errorMessage))
                        return
                    }
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    guard let output = String(data: outputData, encoding: .utf8) else {
                        continuation.resume(throwing: LLMError.parseError("Could not decode CLI output"))
                        return
                    }
                    
                    continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                    
                } catch {
                    timeoutTask.cancel()
                    continuation.resume(throwing: LLMError.networkError(error))
                }
            }
        }
    }
    
    // Conform to LLMProvider protocol (without workingDirectory)
    public func complete(prompt: String, model: String) async throws -> String {
        try await complete(prompt: prompt, model: model, workingDirectory: nil)
    }
    
    public nonisolated func streamComplete(prompt: String, model: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await complete(prompt: prompt, model: model)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func escapeShellArg(_ arg: String) -> String {
        // Escape single quotes for shell
        let escaped = arg.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
