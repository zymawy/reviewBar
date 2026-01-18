import Foundation

/// Protocol for Git platform providers (GitHub, GitLab, Bitbucket)
public protocol GitProvider: Sendable {
    /// Unique identifier for this provider instance
    var id: String { get }
    
    /// Display name (e.g., "GitHub")
    var displayName: String { get }
    
    /// Authenticate with the provider
    func authenticate(token: String) async throws
    
    /// Fetch all pending review requests for the authenticated user
    func fetchReviewRequests() async throws -> [ReviewRequest]
    
    /// Fetch full details of a specific pull request
    func fetchPullRequest(id: String, repo: Repository) async throws -> PullRequest
    
    /// Fetch the diff for a pull request
    func fetchDiff(pr: PullRequest) async throws -> String
    
    /// Post a comment on a pull request
    func postComment(pr: PullRequest, comment: ReviewComment) async throws
    
    /// Submit a full review (approve, request changes, or comment)
    func submitReview(pr: PullRequest, review: ReviewSubmission) async throws
}

// MARK: - Review Submission Types

public struct ReviewComment: Sendable {
    public let body: String
    public let path: String?      // File path for inline comment
    public let line: Int?         // Line number for inline comment
    public let side: DiffSide?    // Which side of the diff
    
    public init(body: String, path: String? = nil, line: Int? = nil, side: DiffSide? = nil) {
        self.body = body
        self.path = path
        self.line = line
        self.side = side
    }
}

public enum DiffSide: String, Sendable {
    case left = "LEFT"
    case right = "RIGHT"
}

public struct ReviewSubmission: Sendable {
    public let body: String
    public let event: ReviewEvent
    public let comments: [ReviewComment]
    
    public init(body: String, event: ReviewEvent, comments: [ReviewComment] = []) {
        self.body = body
        self.event = event
        self.comments = comments
    }
}

public enum ReviewEvent: String, Sendable {
    case approve = "APPROVE"
    case requestChanges = "REQUEST_CHANGES"
    case comment = "COMMENT"
}

// MARK: - Provider Errors

public enum GitProviderError: LocalizedError {
    case notAuthenticated
    case invalidToken
    case rateLimited(retryAfter: TimeInterval?)
    case notFound(String)
    case networkError(Error)
    case apiError(statusCode: Int, message: String)
    case parseError(String)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please configure your access token."
        case .invalidToken:
            return "Invalid access token. Please check your credentials."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Please retry after \(Int(seconds)) seconds."
            }
            return "Rate limited. Please try again later."
        case .notFound(let resource):
            return "Resource not found: \(resource)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .parseError(let message):
            return "Failed to parse response: \(message)"
        }
    }
}
