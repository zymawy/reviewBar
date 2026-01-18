import ArgumentParser
import ReviewBarCore
import Foundation

@main
struct ReviewBarCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reviewbar",
        abstract: "AI-powered code review from the command line",
        version: "1.0.0",
        subcommands: [Review.self, List.self, Status.self]
    )
}

// MARK: - Review Command

struct Review: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Review a specific pull request"
    )
    
    @Option(name: .long, help: "Repository in owner/repo format")
    var repo: String
    
    @Option(name: .long, help: "Pull request number")
    var pr: Int
    
    @Option(name: .long, help: "GitHub Token (or set GITHUB_TOKEN env var)")
    var token: String?
    
    @Option(name: .long, help: "Anthropi API Key (or set ANTHROPIC_API_KEY env var)")
    var apiKey: String?
    
    @Flag(name: .long, help: "Output as JSON")
    var json = false
    
    mutating func run() async throws {
        // 1. Config
        guard let ghToken = token ?? ProcessInfo.processInfo.environment["GITHUB_TOKEN"] else {
            print("Error: GitHub token required (use --token or GITHUB_TOKEN)")
            throw ExitCode.failure
        }
        
        guard let claudeKey = apiKey ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            print("Error: Anthropic API key required (use --api-key or ANTHROPIC_API_KEY)")
            throw ExitCode.failure
        }
        
        print("Initializing ReviewBar...")
        
        // 2. Setup providers
        let gitProvider = GitHubProvider(token: ghToken)
        let llmProvider = ClaudeProvider(apiKey: claudeKey)
        let mcpBridge = MCPBridge() // Loads from default location
        
        let analyzer = ReviewAnalyzer(
            llmProvider: llmProvider,
            mcpBridge: mcpBridge
        )
        
        // 3. Fetch PR
        print("Fetching PR #\(pr) from \(repo)...")
        let repoParts = repo.split(separator: "/")
        guard repoParts.count == 2 else {
            print("Error: Invalid repo format. Use owner/name")
            throw ExitCode.failure
        }
        
        let repository = Repository(owner: String(repoParts[0]), name: String(repoParts[1]))
        
        do {
            let pullRequest = try await gitProvider.fetchPullRequest(id: String(pr), repo: repository)
            let diff = try await gitProvider.fetchDiff(pr: pullRequest)
            
            // 4. Analyze
            print("Analyzing changes (\(pullRequest.additions) additions, \(pullRequest.deletions) deletions)...")
            let result = try await analyzer.analyze(
                pullRequest: pullRequest,
                diffText: diff,
                profile: nil // Use detailed defaults
            )
            
            // 5. Output
            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(result)
                print(String(data: data, encoding: .utf8)!)
            } else {
                printOutput(result)
            }
            
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    func printOutput(_ result: ReviewResult) {
        print("\n=== Review Result: \(result.recommendation.displayName) ===")
        print("Confidence: \(Int(result.confidence * 100))%\n")
        print(result.summary)
        print("\n--- Issues ---")
        for issue in result.issues {
            print("[\(issue.severity.displayName)] \(issue.title) (\(issue.file))")
        }
        print("\n--- Suggestions ---")
        for suggestion in result.suggestions {
            print("💡 \(suggestion.title)")
        }
    }
}

// MARK: - List Command

struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List pending review requests"
    )
    
    @Option(name: .long, help: "GitHub Token (or set GITHUB_TOKEN env var)")
    var token: String?
    
    @Flag(name: .long, help: "Output as JSON")
    var json = false
    
    mutating func run() async throws {
        guard let ghToken = token ?? ProcessInfo.processInfo.environment["GITHUB_TOKEN"] else {
            print("Error: GitHub token required (use --token or GITHUB_TOKEN)")
            throw ExitCode.failure
        }
        
        let provider = GitHubProvider(token: ghToken)
        
        do {
            print("Fetching pending reviews...")
            let requests = try await provider.fetchReviewRequests()
            
            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(requests)
                print(String(data: data, encoding: .utf8)!)
            } else {
                if requests.isEmpty {
                    print("No pending reviews found.")
                } else {
                    print("\nPending Reviews (\(requests.count)):")
                    for request in requests {
                        print("- #\(request.number) \(request.title) (\(request.repository.fullName))")
                    }
                }
            }
        } catch {
            print("Error: \(error)")
            throw ExitCode.failure
        }
    }
}

// MARK: - Status Command

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show ReviewBar status"
    )
    
    func run() throws {
        print("ReviewBar CLI v1.0.0")
        print("Status: Ready")
    }
}
