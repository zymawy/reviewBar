import Foundation

/// Manages cloning PR repositories to temporary directories for CLI-based review
public actor PRCloneManager {
    
    /// Base cache directory for cloned repos
    private let cacheDir: URL
    
    public init() {
        let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDir = cachePath.appendingPathComponent("ReviewBar/repos")
    }
    
    /// Clone a PR's head branch to a temp directory
    /// - Parameters:
    ///   - repoURL: The HTTPS clone URL (e.g., https://github.com/owner/repo.git)
    ///   - branch: The PR's head branch name
    ///   - prNumber: The PR number (for unique directory naming)
    /// - Returns: Path to the cloned directory
    public func clonePR(repoURL: String, branch: String, owner: String, repo: String, prNumber: Int) async throws -> URL {
        // Create unique directory name
        let dirName = "\(owner)_\(repo)_pr\(prNumber)"
        let targetDir = cacheDir.appendingPathComponent(dirName)
        
        // If already exists, remove it first (fresh clone)
        if FileManager.default.fileExists(atPath: targetDir.path) {
            try FileManager.default.removeItem(at: targetDir)
        }
        
        // Ensure parent directory exists
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        // Clone with shallow depth for speed
        let cloneCommand = """
            git clone --branch "\(branch)" --depth 1 "\(repoURL)" "\(targetDir.path)"
            """
        
        let result = try await runShellCommand(cloneCommand)
        
        if result.exitCode != 0 {
            throw PRCloneError.cloneFailed(result.stderr)
        }
        
        return targetDir
    }
    
    /// Cleanup a cloned directory
    public func cleanup(directory: URL) throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }
    
    /// Cleanup all cached repos
    public func cleanupAll() throws {
        if FileManager.default.fileExists(atPath: cacheDir.path) {
            try FileManager.default.removeItem(at: cacheDir)
        }
    }
    
    // MARK: - Shell Execution
    
    private func runShellCommand(_ command: String) async throws -> ShellResult {
        let process = Process()
        // Use login shell to get full environment
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        return ShellResult(
            stdout: String(data: outputData, encoding: .utf8) ?? "",
            stderr: String(data: errorData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }
}

// MARK: - Types

public enum PRCloneError: LocalizedError {
    case cloneFailed(String)
    case directoryNotFound
    
    public var errorDescription: String? {
        switch self {
        case .cloneFailed(let message):
            return "Failed to clone repository: \(message)"
        case .directoryNotFound:
            return "Cloned directory not found"
        }
    }
}

struct ShellResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}
