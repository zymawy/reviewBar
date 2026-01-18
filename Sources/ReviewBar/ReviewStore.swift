import Foundation
import Combine
import ReviewBarCore

/// Manages the state of pending reviews and completed review results
@MainActor
public final class ReviewStore: ObservableObject {
    
    // MARK: - State
    
    @Published public private(set) var pendingReviews: [ReviewRequest] = []
    @Published public private(set) var recentResults: [ReviewResult] = []
    @Published public private(set) var isReviewing: Bool = false
    @Published public private(set) var currentlyReviewing: ReviewRequest?
    @Published public private(set) var lastRefresh: Date?
    @Published public private(set) var lastError: Error?
    
    /// Selected review IDs for batch operations
    @Published public var selectedReviewIds: Set<String> = []
    
    /// Current status message for UI feedback
    @Published public private(set) var statusMessage: String = ""
    
    /// Activity log for debugging/transparency
    @Published public private(set) var activityLog: [LogEntry] = []
    
    public struct LogEntry: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let message: String
        public let level: LogLevel
        
        public enum LogLevel: String {
            case info = "ℹ️"
            case success = "✅"
            case warning = "⚠️"
            case error = "❌"
        }
    }
    
    public func log(_ message: String, level: LogEntry.LogLevel = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, level: level)
        activityLog.insert(entry, at: 0)
        if activityLog.count > 100 { activityLog.removeLast() }
        print("[\(level.rawValue)] \(message)")
    }
    
    // MARK: - Dependencies
    
    private var gitProviders: [any GitProvider] = []
    private var reviewAnalyzer: ReviewAnalyzer?
    private let cloneManager = PRCloneManager()
    private var useCLIProvider = false
    
    // MARK: - Constants
    
    private let maxRecentResults = 20
    
    // MARK: - Init
    
    public init() {
        // Providers will be configured when settings are available
    }
    
    // MARK: - Configuration
    
    public func configure(
        gitProviders: [any GitProvider],
        reviewAnalyzer: ReviewAnalyzer,
        useCLI: Bool = false
    ) {
        self.gitProviders = gitProviders
        self.reviewAnalyzer = reviewAnalyzer
        self.useCLIProvider = useCLI
    }
    
    // MARK: - Refresh
    
    public func refresh() async {
        guard !gitProviders.isEmpty else {
            print("ReviewStore: No providers configured")
            return
        }
        
        lastError = nil
        
        do {
            var allRequests: [ReviewRequest] = []
            
            for provider in gitProviders {
                let requests = try await provider.fetchReviewRequests()
                allRequests.append(contentsOf: requests)
            }
            
            // Sort by creation date (newest first)
            allRequests.sort { $0.createdAt > $1.createdAt }
            
            pendingReviews = allRequests
            lastRefresh = Date()
            
            // Clear selection if it's no longer valid
            let validIds = Set(pendingReviews.map { $0.id })
            selectedReviewIds = selectedReviewIds.intersection(validIds)
            
        } catch {
            lastError = error
            print("ReviewStore: Refresh failed: \(error)")
        }
    }
    
    public func clearError() {
        lastError = nil
    }
    
    // MARK: - Review Operations
    
    public func startReview(_ request: ReviewRequest) async -> ReviewResult? {
        guard let analyzer = reviewAnalyzer else {
            lastError = ReviewError.notConfigured
            return nil
        }
        
        guard !isReviewing else {
            lastError = ReviewError.alreadyReviewing
            log("Already reviewing another PR", level: .warning)
            return nil
        }
        
        isReviewing = true
        currentlyReviewing = request
        statusMessage = "Starting review for \(request.title)..."
        HapticManager.trigger(.generic)
        log("Starting review for PR #\(request.number): \(request.title)")
        
        var clonedDir: URL? = nil
        
        defer {
            isReviewing = false
            currentlyReviewing = nil
            statusMessage = ""
            
            // Cleanup cloned directory
            if let dir = clonedDir {
                Task {
                    try? await cloneManager.cleanup(directory: dir)
                    await MainActor.run { log("Cleaned up temp directory", level: .info) }
                }
            }
        }
        
        do {
            // Find the provider for this request
            guard let provider = gitProviders.first(where: { $0.id == request.providerID }) else {
                throw ReviewError.providerNotFound
            }
            
            // Fetch full PR details
            statusMessage = "Fetching PR details..."
            log("Fetching PR details from GitHub...")
            let pullRequest = try await provider.fetchPullRequest(
                id: request.pullRequestID,
                repo: request.repository
            )
            log("Fetched PR: \(pullRequest.title)", level: .success)
            
            // Fetch diff
            statusMessage = "Fetching code diff..."
            log("Fetching code diff...")
            let diff = try await provider.fetchDiff(pr: pullRequest)
            log("Fetched diff: \(diff.count) characters", level: .success)
            
            // Clone repo if using CLI provider
            if useCLIProvider {
                statusMessage = "Cloning repository..."
                log("Cloning repository to temp directory...")
                let repoURL = "https://github.com/\(request.repository.fullName).git"
                clonedDir = try await cloneManager.clonePR(
                    repoURL: repoURL,
                    branch: pullRequest.headBranch,
                    owner: request.repository.owner,
                    repo: request.repository.name,
                    prNumber: request.number
                )
                if let dir = clonedDir {
                    log("Cloned to \(dir.path)", level: .success)
                }
            }
            
            // Analyze
            statusMessage = "🤖 AI is analyzing code..."
            log("Sending to AI for analysis...")
            let result = try await analyzer.analyze(
                pullRequest: pullRequest,
                diffText: diff,
                profile: nil,
                workingDirectory: clonedDir
            )
            log("Review complete! Found \(result.issues.count) issues", level: .success)
            
            // Store result
            addResult(result)
            
            // Remove from pending
            pendingReviews.removeAll { $0.id == request.id }
            
            // Post notification
            NotificationCenter.default.post(
                name: .reviewDidComplete,
                object: nil,
                userInfo: ["result": result]
            )
            
            // Track in analytics
            AnalyticsService.shared.track(result: result)
            
            // Play success sound and trigger haptic
            SoundManager.playSuccess()
            HapticManager.success()
            
            return result
            
        } catch {
            lastError = error
            log("Review failed: \(error.localizedDescription)", level: .error)
            SoundManager.playError()
            HapticManager.error()
            return nil
        }
    }
    
    // MARK: - Batch Review
    
    public func startBatchReview() async {
        guard !selectedReviewIds.isEmpty else { return }
        
        let reviewsToRun = pendingReviews.filter { selectedReviewIds.contains($0.id) }
        log("Starting batch review of \(reviewsToRun.count) items", level: .info)
        
        for request in reviewsToRun {
            guard !Task.isCancelled else { break }
            _ = await startReview(request)
        }
        
        selectedReviewIds.removeAll()
        log("Batch review complete", level: .success)
    }
    
    public func postReview(_ result: ReviewResult) async throws {
        guard let provider = gitProviders.first else {
            throw ReviewError.notConfigured
        }
        
        // 1. Convert Issues/Suggestions to Comments
        var comments: [ReviewComment] = []
        
        for issue in result.issues {
            if let range = issue.lineRange {
                // Determine side (new/right side)
                comments.append(ReviewComment(
                    body: "[\(issue.severity.displayName)] **\(issue.title)**\n\n\(issue.description)",
                    path: issue.file,
                    line: range.upperBound,
                    side: .right
                ))
            }
        }
        
        for suggestion in result.suggestions {
            if let range = suggestion.lineRange {
                var body = "💡 **Suggestion**: \(suggestion.title)\n\n\(suggestion.description)"
                if let code = suggestion.suggestedCode {
                    body += "\n```suggestion\n\(code)\n```"
                }
                
                comments.append(ReviewComment(
                    body: body,
                    path: suggestion.file,
                    line: range.upperBound,
                    side: .right
                ))
            }
        }
        
        // 2. Determine Event
        let event: ReviewEvent
        switch result.recommendation {
        case .approve: event = .approve
        case .requestChanges: event = .requestChanges
        case .comment: event = .comment
        }
        
        // 3. Create Submission
        let submission = ReviewSubmission(
            body: result.summary + "\n\n---\n*Generated by ReviewBar*",
            event: event,
            comments: comments
        )
        
        // 4. Reconstruct PR (minimal needed for provider)
        // We split "owner/repo" string
        let repoParts = result.pullRequest.repository.split(separator: "/")
        guard repoParts.count == 2 else { throw ReviewError.analysisFailure("Invalid repo name") }
        
        let repo = Repository(
            owner: String(repoParts[0]),
            name: String(repoParts[1])
        )
        
        let pr = PullRequest(
            id: result.pullRequest.id,
            number: result.pullRequest.number,
            title: result.pullRequest.title,
            body: nil,
            state: .open,
            author: Author(login: result.pullRequest.author, avatarURL: nil),
            repository: repo,
            baseBranch: "", // Not needed for posting
            headBranch: "",
            createdAt: Date(),
            updatedAt: Date(),
            additions: 0,
            deletions: 0,
            changedFiles: 0,
            isDraft: false,
            labels: [],
            url: result.pullRequest.url
        )
        
        // 5. Submit
        try await provider.submitReview(pr: pr, review: submission)
    }
    
    public func cancelReview() {
        isReviewing = false
        currentlyReviewing = nil
    }
    
    // MARK: - Results Management
    
    private func addResult(_ result: ReviewResult) {
        recentResults.insert(result, at: 0)
        
        // Trim to max
        if recentResults.count > maxRecentResults {
            recentResults = Array(recentResults.prefix(maxRecentResults))
        }
    }
    
    public func clearResults() {
        recentResults.removeAll()
    }
    
    public func dismissPendingReview(_ request: ReviewRequest) {
        pendingReviews.removeAll { $0.id == request.id }
    }
}

// MARK: - Errors

public enum ReviewError: LocalizedError {
    case notConfigured
    case alreadyReviewing
    case providerNotFound
    case analysisFailure(String)
    
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Review analyzer is not configured"
        case .alreadyReviewing:
            return "A review is already in progress"
        case .providerNotFound:
            return "Git provider not found for this repository"
        case .analysisFailure(let message):
            return "Analysis failed: \(message)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    public static let reviewDidComplete = Notification.Name("ReviewBarReviewDidComplete")
}
