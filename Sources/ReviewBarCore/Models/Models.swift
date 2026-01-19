import Foundation

// MARK: - Pull Request

/// A pull request from any Git provider
public struct PullRequest: Sendable, Codable, Identifiable {
    public let id: String
    public let number: Int
    public let title: String
    public let body: String?
    public let state: PRState
    public let author: Author
    public let repository: Repository
    public let baseBranch: String
    public let headBranch: String
    public let createdAt: Date
    public let updatedAt: Date
    public let additions: Int
    public let deletions: Int
    public let changedFiles: Int
    public let isDraft: Bool
    public let labels: [String]
    public let url: URL
    
    public init(
        id: String,
        number: Int,
        title: String,
        body: String?,
        state: PRState,
        author: Author,
        repository: Repository,
        baseBranch: String,
        headBranch: String,
        createdAt: Date,
        updatedAt: Date,
        additions: Int,
        deletions: Int,
        changedFiles: Int,
        isDraft: Bool,
        labels: [String],
        url: URL
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.body = body
        self.state = state
        self.author = author
        self.repository = repository
        self.baseBranch = baseBranch
        self.headBranch = headBranch
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.additions = additions
        self.deletions = deletions
        self.changedFiles = changedFiles
        self.isDraft = isDraft
        self.labels = labels
        self.url = url
    }
}

public enum PRState: String, Codable, Sendable {
    case open
    case closed
    case merged
}

public struct Author: Sendable, Codable {
    public let login: String
    public let avatarURL: URL?
    
    public init(login: String, avatarURL: URL?) {
        self.login = login
        self.avatarURL = avatarURL
    }
}

public struct Repository: Sendable, Codable, Hashable {
    public let owner: String
    public let name: String
    public let fullName: String
    public let url: URL?
    
    public init(owner: String, name: String, url: URL? = nil) {
        self.owner = owner
        self.name = name
        self.fullName = "\(owner)/\(name)"
        self.url = url
    }
}

// MARK: - Review Request

/// A pending review request (you've been asked to review)
public struct ReviewRequest: Sendable, Codable, Identifiable {
    public let id: String
    public let pullRequestID: String
    public let number: Int
    public let title: String
    public let repository: Repository
    public let author: Author
    public let createdAt: Date
    public let providerID: String
    public let priority: ReviewPriority
    
    public init(
        id: String,
        pullRequestID: String,
        number: Int,
        title: String,
        repository: Repository,
        author: Author,
        createdAt: Date,
        providerID: String,
        priority: ReviewPriority = .normal
    ) {
        self.id = id
        self.pullRequestID = pullRequestID
        self.number = number
        self.title = title
        self.repository = repository
        self.author = author
        self.createdAt = createdAt
        self.providerID = providerID
        self.priority = priority
    }
}

public enum ReviewPriority: String, Codable, Sendable, Comparable {
    case low
    case normal
    case high
    case critical
    
    public static func < (lhs: ReviewPriority, rhs: ReviewPriority) -> Bool {
        let order: [ReviewPriority] = [.low, .normal, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else { return false }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Review Result

/// The result of an AI-powered code review
public struct ReviewResult: Sendable, Codable, Identifiable {
    public let id: UUID
    public let pullRequest: PullRequestSummary
    public let analyzedAt: Date
    public let duration: TimeInterval
    
    public let summary: String
    public let recommendation: ReviewRecommendation
    public let confidence: Double
    
    public let issues: [ReviewIssue]
    public let suggestions: [ReviewSuggestion]
    public let positives: [ReviewPositive]
    
    public let skillResults: [SkillResult]
    public let tokenUsage: TokenUsage?
    public let diff: String?
    
    public init(
        id: UUID = UUID(),
        pullRequest: PullRequestSummary,
        analyzedAt: Date = Date(),
        duration: TimeInterval,
        summary: String,
        recommendation: ReviewRecommendation,
        confidence: Double,
        issues: [ReviewIssue],
        suggestions: [ReviewSuggestion],
        positives: [ReviewPositive],
        skillResults: [SkillResult] = [],
        tokenUsage: TokenUsage? = nil,
        diff: String? = nil
    ) {
        self.id = id
        self.pullRequest = pullRequest
        self.analyzedAt = analyzedAt
        self.duration = duration
        self.summary = summary
        self.recommendation = recommendation
        self.confidence = confidence
        self.issues = issues
        self.suggestions = suggestions
        self.positives = positives
        self.skillResults = skillResults
        self.tokenUsage = tokenUsage
        self.diff = diff
    }
}

public struct PullRequestSummary: Sendable, Codable {
    public let id: String
    public let number: Int
    public let title: String
    public let repository: String
    public let author: String
    public let additions: Int
    public let deletions: Int
    public let changedFiles: Int
    public let url: URL
    
    public init(from pr: PullRequest) {
        self.id = pr.id
        self.number = pr.number
        self.title = pr.title
        self.repository = pr.repository.fullName
        self.author = pr.author.login
        self.additions = pr.additions
        self.deletions = pr.deletions
        self.changedFiles = pr.changedFiles
        self.url = pr.url
    }
    
    public init(
        id: String,
        number: Int,
        title: String,
        repository: String,
        author: String,
        additions: Int,
        deletions: Int,
        changedFiles: Int,
        url: URL
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.repository = repository
        self.author = author
        self.additions = additions
        self.deletions = deletions
        self.changedFiles = changedFiles
        self.url = url
    }
}

public enum ReviewRecommendation: String, Codable, Sendable {
    case approve
    case requestChanges
    case comment
    
    public var displayName: String {
        switch self {
        case .approve: return "Approve"
        case .requestChanges: return "Request Changes"
        case .comment: return "Comment"
        }
    }
    
    public var emoji: String {
        switch self {
        case .approve: return "✅"
        case .requestChanges: return "🔴"
        case .comment: return "💬"
        }
    }
}

// MARK: - Review Issues

public struct ReviewIssue: Sendable, Codable, Identifiable {
    public let id: UUID
    public let severity: IssueSeverity
    public let category: IssueCategory
    public let file: String
    public let lineRange: ClosedRange<Int>?
    public let title: String
    public let description: String
    public let suggestedFix: String?
    public let codeSnippet: String?
    
    public init(
        id: UUID = UUID(),
        severity: IssueSeverity,
        category: IssueCategory,
        file: String,
        lineRange: ClosedRange<Int>? = nil,
        title: String,
        description: String,
        suggestedFix: String? = nil,
        codeSnippet: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.category = category
        self.file = file
        self.lineRange = lineRange
        self.title = title
        self.description = description
        self.suggestedFix = suggestedFix
        self.codeSnippet = codeSnippet
    }
}

public enum IssueSeverity: String, Codable, Sendable, CaseIterable {
    case critical
    case warning
    case info
    
    public var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .warning: return "Warning"
        case .info: return "Info"
        }
    }
    
    public var emoji: String {
        switch self {
        case .critical: return "🔴"
        case .warning: return "🟡"
        case .info: return "🔵"
        }
    }
}

public enum IssueCategory: String, Codable, Sendable, CaseIterable {
    case security
    case performance
    case logic
    case style
    case test
    case documentation
    case accessibility
    case other
    
    public var displayName: String {
        switch self {
        case .security: return "Security"
        case .performance: return "Performance"
        case .logic: return "Logic"
        case .style: return "Style"
        case .test: return "Testing"
        case .documentation: return "Documentation"
        case .accessibility: return "Accessibility"
        case .other: return "Other"
        }
    }
}

public struct ReviewSuggestion: Sendable, Codable, Identifiable {
    public let id: UUID
    public let file: String
    public let lineRange: ClosedRange<Int>?
    public let title: String
    public let description: String
    public let suggestedCode: String?
    
    public init(
        id: UUID = UUID(),
        file: String,
        lineRange: ClosedRange<Int>? = nil,
        title: String,
        description: String,
        suggestedCode: String? = nil
    ) {
        self.id = id
        self.file = file
        self.lineRange = lineRange
        self.title = title
        self.description = description
        self.suggestedCode = suggestedCode
    }
}

public struct ReviewPositive: Sendable, Codable, Identifiable {
    public let id: UUID
    public let file: String?
    public let title: String
    public let description: String
    
    public init(
        id: UUID = UUID(),
        file: String? = nil,
        title: String,
        description: String
    ) {
        self.id = id
        self.file = file
        self.title = title
        self.description = description
    }
}

// MARK: - Skill Results

public struct SkillResult: Sendable, Codable, Identifiable {
    public let id: UUID
    public let skillName: String
    public let passed: Bool
    public let findings: [SkillFinding]
    public let executionTime: TimeInterval
    
    public init(
        id: UUID = UUID(),
        skillName: String,
        passed: Bool,
        findings: [SkillFinding],
        executionTime: TimeInterval
    ) {
        self.id = id
        self.skillName = skillName
        self.passed = passed
        self.findings = findings
        self.executionTime = executionTime
    }
}

public struct SkillFinding: Sendable, Codable {
    public let ruleID: String
    public let message: String
    public let file: String?
    public let line: Int?
    public let severity: IssueSeverity
    
    public init(
        ruleID: String,
        message: String,
        file: String? = nil,
        line: Int? = nil,
        severity: IssueSeverity
    ) {
        self.ruleID = ruleID
        self.message = message
        self.file = file
        self.line = line
        self.severity = severity
    }
}

// MARK: - Token Usage

public struct TokenUsage: Sendable, Codable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int
    public let estimatedCost: Double?
    
    public init(inputTokens: Int, outputTokens: Int, estimatedCost: Double? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = inputTokens + outputTokens
        self.estimatedCost = estimatedCost
    }
}



public enum TriggerCondition: String, Codable, Sendable, CaseIterable {
    case onAssign
    case onMention
    case manual
    case all
    
    public var displayName: String {
        switch self {
        case .onAssign: return "When assigned as reviewer"
        case .onMention: return "When mentioned in PR"
        case .manual: return "Manual only"
        case .all: return "All PRs in watched repos"
        }
    }
}

public struct InlineRule: Sendable, Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var pattern: String?  // Regex pattern
    public var check: String?    // Natural language check
    public var severity: IssueSeverity
    public var message: String
    
    public init(
        id: UUID = UUID(),
        name: String,
        pattern: String? = nil,
        check: String? = nil,
        severity: IssueSeverity = .warning,
        message: String
    ) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.check = check
        self.severity = severity
        self.message = message
    }
}
