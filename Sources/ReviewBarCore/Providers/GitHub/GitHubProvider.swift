import Foundation

/// GitHub API client implementing GitProvider protocol
public actor GitHubProvider: GitProvider {
    
    // MARK: - Properties
    
    public nonisolated let id: String = "github"
    public nonisolated let displayName: String = "GitHub"
    
    private var token: String?
    private let session: URLSession
    private let baseURL = URL(string: "https://api.github.com")!
    private let decoder: JSONDecoder
    
    // MARK: - Init
    
    public init(token: String? = nil) {
        self.token = token
        
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28"
        ]
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // MARK: - Authentication
    
    public func authenticate(token: String) async throws {
        self.token = token
        
        // Validate token by fetching user
        let url = baseURL.appendingPathComponent("user")
        let (_, response) = try await request(url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitProviderError.networkError(URLError(.badServerResponse))
        }
        
        switch httpResponse.statusCode {
        case 200:
            return // Success
        case 401:
            self.token = nil
            throw GitProviderError.invalidToken
        default:
            throw GitProviderError.apiError(
                statusCode: httpResponse.statusCode,
                message: "Failed to authenticate"
            )
        }
    }
    
    // MARK: - Fetch Review Requests
    
    public func fetchReviewRequests() async throws -> [ReviewRequest] {
        guard token != nil else {
            throw GitProviderError.notAuthenticated
        }
        
        // Search for PRs where user is requested reviewer
        let query = "is:pr is:open review-requested:@me"
        var components = URLComponents(url: baseURL.appendingPathComponent("search/issues"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "per_page", value: "50")
        ]
        
        let (data, _) = try await request(components.url!)
        
        let searchResult = try decoder.decode(GitHubSearchResult.self, from: data)
        
        return searchResult.items.map { item in
            // Parse repository from URL
            let repo = parseRepository(from: item.repositoryUrl)
            
            return ReviewRequest(
                id: "github-\(item.id)",
                pullRequestID: String(item.number),
                number: item.number,
                title: item.title,
                repository: repo,
                author: Author(login: item.user.login, avatarURL: URL(string: item.user.avatarUrl)),
                createdAt: item.createdAt,
                providerID: id,
                priority: determinePriority(item)
            )
        }
    }
    
    // MARK: - Fetch Pull Request
    
    public func fetchPullRequest(id: String, repo: Repository) async throws -> PullRequest {
        guard token != nil else {
            throw GitProviderError.notAuthenticated
        }
        
        let url = baseURL
            .appendingPathComponent("repos")
            .appendingPathComponent(repo.fullName)
            .appendingPathComponent("pulls")
            .appendingPathComponent(id)
        
        let (data, _) = try await request(url)
        let ghPR = try decoder.decode(GitHubPullRequest.self, from: data)
        
        return PullRequest(
            id: String(ghPR.id),
            number: ghPR.number,
            title: ghPR.title,
            body: ghPR.body,
            state: ghPR.state == "open" ? .open : (ghPR.merged == true ? .merged : .closed),
            author: Author(login: ghPR.user.login, avatarURL: URL(string: ghPR.user.avatarUrl)),
            repository: repo,
            baseBranch: ghPR.base.ref,
            headBranch: ghPR.head.ref,
            createdAt: ghPR.createdAt,
            updatedAt: ghPR.updatedAt,
            additions: ghPR.additions,
            deletions: ghPR.deletions,
            changedFiles: ghPR.changedFiles,
            isDraft: ghPR.draft,
            labels: ghPR.labels.map { $0.name },
            url: ghPR.htmlUrl
        )
    }
    
    // MARK: - Fetch Diff
    
    public func fetchDiff(pr: PullRequest) async throws -> String {
        guard token != nil else {
            throw GitProviderError.notAuthenticated
        }
        
        let url = baseURL
            .appendingPathComponent("repos")
            .appendingPathComponent(pr.repository.fullName)
            .appendingPathComponent("pulls")
            .appendingPathComponent(String(pr.number))
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3.diff", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token!)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        try checkResponse(response, data: data)
        
        guard let diff = String(data: data, encoding: .utf8) else {
            throw GitProviderError.parseError("Failed to decode diff as UTF-8")
        }
        
        return diff
    }
    
    // MARK: - Post Comment
    
    public func postComment(pr: PullRequest, comment: ReviewComment) async throws {
        guard token != nil else {
            throw GitProviderError.notAuthenticated
        }
        
        let url: URL
        var body: [String: Any] = ["body": comment.body]
        
        if let path = comment.path, let line = comment.line {
            // Inline comment on a specific file/line
            url = baseURL
                .appendingPathComponent("repos")
                .appendingPathComponent(pr.repository.fullName)
                .appendingPathComponent("pulls")
                .appendingPathComponent(String(pr.number))
                .appendingPathComponent("comments")
            
            body["path"] = path
            body["line"] = line
            body["side"] = comment.side?.rawValue ?? "RIGHT"
        } else {
            // General issue comment
            url = baseURL
                .appendingPathComponent("repos")
                .appendingPathComponent(pr.repository.fullName)
                .appendingPathComponent("issues")
                .appendingPathComponent(String(pr.number))
                .appendingPathComponent("comments")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await self.request(request)
        try checkResponse(response, data: data)
    }
    
    // MARK: - Submit Review
    
    public func submitReview(pr: PullRequest, review: ReviewSubmission) async throws {
        guard token != nil else {
            throw GitProviderError.notAuthenticated
        }
        
        let url = baseURL
            .appendingPathComponent("repos")
            .appendingPathComponent(pr.repository.fullName)
            .appendingPathComponent("pulls")
            .appendingPathComponent(String(pr.number))
            .appendingPathComponent("reviews")
        
        var body: [String: Any] = [
            "body": review.body,
            "event": review.event.rawValue
        ]
        
        if !review.comments.isEmpty {
            body["comments"] = review.comments.compactMap { comment -> [String: Any]? in
                guard let path = comment.path, let line = comment.line else { return nil }
                return [
                    "path": path,
                    "line": line,
                    "body": comment.body,
                    "side": comment.side?.rawValue ?? "RIGHT"
                ]
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await self.request(request)
        try checkResponse(response, data: data)
    }
    
    // MARK: - Helpers
    
    private func request(_ url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await self.request(request)
    }
    
    private func request(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var request = request
        if let token = token, request.value(forHTTPHeaderField: "Authorization") == nil {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            try checkResponse(response, data: data)
            return (data, response)
        } catch let error as GitProviderError {
            throw error
        } catch {
            throw GitProviderError.networkError(error)
        }
    }
    
    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitProviderError.networkError(URLError(.badServerResponse))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return // Success
        case 401:
            throw GitProviderError.invalidToken
        case 403:
            if let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After"),
               let seconds = TimeInterval(retryAfter) {
                throw GitProviderError.rateLimited(retryAfter: seconds)
            }
            throw GitProviderError.rateLimited(retryAfter: nil)
        case 404:
            throw GitProviderError.notFound("Resource not found")
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitProviderError.apiError(statusCode: httpResponse.statusCode, message: message)
        }
    }
    
    private func parseRepository(from urlString: String) -> Repository {
        // URL format: https://api.github.com/repos/owner/name
        let components = urlString.components(separatedBy: "/")
        if components.count >= 2 {
            let name = components[components.count - 1]
            let owner = components[components.count - 2]
            return Repository(owner: owner, name: name)
        }
        return Repository(owner: "unknown", name: "unknown")
    }
    
    private func determinePriority(_ item: GitHubSearchItem) -> ReviewPriority {
        // Determine priority based on labels and age
        let labels = Set(item.labels.map { $0.name.lowercased() })
        
        if labels.contains("critical") || labels.contains("urgent") || labels.contains("hotfix") {
            return .critical
        }
        if labels.contains("high-priority") || labels.contains("important") {
            return .high
        }
        if labels.contains("low-priority") || labels.contains("minor") {
            return .low
        }
        
        // Age-based priority boost
        let age = Date().timeIntervalSince(item.createdAt)
        if age > 7 * 24 * 60 * 60 { // Over 7 days old
            return .high
        }
        
        return .normal
    }
}

// MARK: - GitHub API Models

private struct GitHubSearchResult: Decodable {
    let totalCount: Int
    let items: [GitHubSearchItem]
}

private struct GitHubSearchItem: Decodable {
    let id: Int
    let number: Int
    let title: String
    let state: String
    let user: GitHubUser
    let createdAt: Date
    let updatedAt: Date
    let labels: [GitHubLabel]
    let repositoryUrl: String
}

private struct GitHubPullRequest: Decodable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: String
    let user: GitHubUser
    let createdAt: Date
    let updatedAt: Date
    let merged: Bool?
    let draft: Bool
    let additions: Int
    let deletions: Int
    let changedFiles: Int
    let labels: [GitHubLabel]
    let base: GitHubBranch
    let head: GitHubBranch
    let htmlUrl: URL
}

private struct GitHubUser: Decodable {
    let login: String
    let avatarUrl: String
}

private struct GitHubLabel: Decodable {
    let name: String
}

private struct GitHubBranch: Decodable {
    let ref: String
    let sha: String
}
