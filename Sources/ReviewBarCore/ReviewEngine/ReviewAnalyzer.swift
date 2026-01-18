import Foundation

/// Orchestrates the AI-powered code review process
public actor ReviewAnalyzer {
    
    // MARK: - Dependencies
    
    private let llmProvider: any LLMProvider
    private let mcpBridge: MCPBridge?
    private let diffParser: DiffParser
    
    // MARK: - Init
    
    public init(
        llmProvider: any LLMProvider,
        mcpBridge: MCPBridge? = nil
    ) {
        self.llmProvider = llmProvider
        self.mcpBridge = mcpBridge
        self.diffParser = DiffParser()
    }
    
    // MARK: - Analysis
    
    public func analyze(
        pullRequest: PullRequest,
        diffText: String,
        profile: ReviewProfile?,
        workingDirectory: URL? = nil
    ) async throws -> ReviewResult {
        let startTime = Date()
        
        // 1. Parse the diff
        let parsedDiff = diffParser.parse(diffText)
        
        // 2. Run skill-based checks if available
        var skillResults: [SkillResult] = []
        if let bridge = mcpBridge {
            skillResults = await bridge.executeSkills(
                diff: parsedDiff,
                skillIDs: profile?.skillIDs ?? []
            )
        }
        
        // 3. Build the prompt
        let prompt = buildPrompt(
            pullRequest: pullRequest,
            diff: parsedDiff,
            skillFindings: skillResults.flatMap { $0.findings },
            profile: profile
        )
        
        // 4. Call LLM
        let model = profile?.llmModel ?? "claude-3-5-sonnet-20241022"
        let response: String
        
        // Check if LLM provider supports working directory (CLI-based)
        if let cliProvider = llmProvider as? CLILLMProvider {
            response = try await cliProvider.complete(prompt: prompt, model: model, workingDirectory: workingDirectory)
        } else {
            response = try await llmProvider.complete(prompt: prompt, model: model)
        }
        
        // 5. Parse response
        let parsed = parseResponse(response)
        
        // 6. Build result
        let duration = Date().timeIntervalSince(startTime)
        
        return ReviewResult(
            pullRequest: PullRequestSummary(from: pullRequest),
            duration: duration,
            summary: parsed.summary,
            recommendation: parsed.recommendation,
            confidence: parsed.confidence,
            issues: parsed.issues,
            suggestions: parsed.suggestions,
            positives: parsed.positives,
            skillResults: skillResults,
            tokenUsage: nil // TODO: Get from LLM response
        )
    }
    
    // MARK: - Prompt Building
    
    private func buildPrompt(
        pullRequest: PullRequest,
        diff: ParsedDiff,
        skillFindings: [SkillFinding],
        profile: ReviewProfile?
    ) -> String {
        var prompt = """
        You are an expert code reviewer. Analyze this pull request and provide a detailed review.
        
        ## Pull Request Information
        
        **Title:** \(pullRequest.title)
        **Author:** \(pullRequest.author.login)
        **Repository:** \(pullRequest.repository.fullName)
        **Branch:** \(pullRequest.headBranch) → \(pullRequest.baseBranch)
        **Changes:** +\(pullRequest.additions) / -\(pullRequest.deletions) in \(pullRequest.changedFiles) files
        
        """
        
        if let body = pullRequest.body, !body.isEmpty {
            prompt += """
            
            **Description:**
            \(body)
            
            """
        }
        
        // Add skill findings if any
        if !skillFindings.isEmpty {
            prompt += """
            
            ## Automated Checks (from custom rules)
            
            The following issues were found by automated rules:
            
            """
            
            for finding in skillFindings {
                let location = [finding.file, finding.line.map { "line \($0)" }]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                
                prompt += "- [\(finding.severity.displayName)] \(finding.message)"
                if !location.isEmpty {
                    prompt += " (\(location))"
                }
                prompt += "\n"
            }
        }
        
        // Add custom rules from profile
        if let rules = profile?.customRules, !rules.isEmpty {
            prompt += """
            
            ## Review Guidelines
            
            Pay special attention to these rules:
            
            """
            
            for rule in rules {
                prompt += "- \(rule.name): \(rule.message)\n"
            }
        }
        
        // Add diff (truncated if too large)
        let diffText = formatDiff(diff, maxLines: 2000)
        prompt += """
        
        ## Code Changes
        
        ```diff
        \(diffText)
        ```
        
        ## Your Review
        
        Please provide your review in the following JSON format:
        
        ```json
        {
          "summary": "Brief summary of the changes and overall assessment",
          "recommendation": "approve" | "requestChanges" | "comment",
          "confidence": 0.0-1.0,
          "issues": [
            {
              "severity": "critical" | "warning" | "info",
              "category": "security" | "performance" | "logic" | "style" | "test" | "documentation",
              "file": "path/to/file",
              "lineRange": [start, end] or null,
              "title": "Short issue title",
              "description": "Detailed explanation",
              "suggestedFix": "Optional code suggestion"
            }
          ],
          "suggestions": [
            {
              "file": "path/to/file",
              "title": "Improvement suggestion",
              "description": "Why this would be better",
              "suggestedCode": "Optional code"
            }
          ],
          "positives": [
            {
              "title": "What was done well",
              "description": "Why this is good"
            }
          ]
        }
        ```
        
        Focus on:
        1. Security vulnerabilities (critical)
        2. Performance issues
        3. Logic errors or edge cases
        4. Code style and best practices
        5. Test coverage
        6. Documentation
        
        Be constructive and specific. Reference exact lines when possible.
        """
        
        return prompt
    }
    
    private func formatDiff(_ diff: ParsedDiff, maxLines: Int) -> String {
        var lines: [String] = []
        var lineCount = 0
        
        for file in diff.files {
            if lineCount >= maxLines {
                lines.append("\n... (truncated, \(diff.files.count - diff.files.firstIndex(where: { $0.path == file.path })!) more files)")
                break
            }
            
            lines.append("--- a/\(file.path)")
            lines.append("+++ b/\(file.path)")
            lineCount += 2
            
            for hunk in file.hunks {
                if lineCount >= maxLines {
                    lines.append("... (truncated)")
                    break
                }
                
                lines.append("@@ -\(hunk.oldStart),\(hunk.oldCount) +\(hunk.newStart),\(hunk.newCount) @@")
                lineCount += 1
                
                for line in hunk.lines {
                    if lineCount >= maxLines {
                        lines.append("... (truncated)")
                        break
                    }
                    
                    let prefix: String
                    switch line.type {
                    case .addition: prefix = "+"
                    case .deletion: prefix = "-"
                    case .context: prefix = " "
                    }
                    
                    lines.append(prefix + line.content)
                    lineCount += 1
                }
            }
            
            lines.append("")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Response Parsing
    
    private struct ParsedResponse {
        var summary: String
        var recommendation: ReviewRecommendation
        var confidence: Double
        var issues: [ReviewIssue]
        var suggestions: [ReviewSuggestion]
        var positives: [ReviewPositive]
    }
    
    private func parseResponse(_ response: String) -> ParsedResponse {
        // Try to extract JSON from the response
        var jsonString = response
        
        // Look for JSON in code blocks
        if let jsonStart = response.range(of: "```json"),
           let jsonEnd = response.range(of: "```", range: jsonStart.upperBound..<response.endIndex) {
            jsonString = String(response[jsonStart.upperBound..<jsonEnd.lowerBound])
        } else if let jsonStart = response.range(of: "{"),
                  let jsonEnd = response.range(of: "}", options: .backwards) {
            jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
        }
        
        // Parse JSON
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Fallback if JSON parsing fails
            return ParsedResponse(
                summary: response,
                recommendation: .comment,
                confidence: 0.5,
                issues: [],
                suggestions: [],
                positives: []
            )
        }
        
        // Extract values
        let summary = json["summary"] as? String ?? "Review completed"
        
        let recommendationStr = json["recommendation"] as? String ?? "comment"
        let recommendation: ReviewRecommendation = {
            switch recommendationStr.lowercased() {
            case "approve": return .approve
            case "requestchanges", "request_changes": return .requestChanges
            default: return .comment
            }
        }()
        
        let confidence = json["confidence"] as? Double ?? 0.7
        
        // Parse issues
        let issuesArray = json["issues"] as? [[String: Any]] ?? []
        let issues = issuesArray.map { parseIssue($0) }
        
        // Parse suggestions
        let suggestionsArray = json["suggestions"] as? [[String: Any]] ?? []
        let suggestions = suggestionsArray.map { parseSuggestion($0) }
        
        // Parse positives
        let positivesArray = json["positives"] as? [[String: Any]] ?? []
        let positives = positivesArray.map { parsePositive($0) }
        
        return ParsedResponse(
            summary: summary,
            recommendation: recommendation,
            confidence: min(max(confidence, 0), 1),
            issues: issues,
            suggestions: suggestions,
            positives: positives
        )
    }
    
    private func parseIssue(_ dict: [String: Any]) -> ReviewIssue {
        let severityStr = dict["severity"] as? String ?? "warning"
        let severity: IssueSeverity = {
            switch severityStr.lowercased() {
            case "critical": return .critical
            case "info": return .info
            default: return .warning
            }
        }()
        
        let categoryStr = dict["category"] as? String ?? "other"
        let category: IssueCategory = IssueCategory(rawValue: categoryStr.lowercased()) ?? .other
        
        var lineRange: ClosedRange<Int>? = nil
        if let range = dict["lineRange"] as? [Int], range.count == 2 {
            lineRange = range[0]...range[1]
        }
        
        return ReviewIssue(
            severity: severity,
            category: category,
            file: dict["file"] as? String ?? "unknown",
            lineRange: lineRange,
            title: dict["title"] as? String ?? "Issue",
            description: dict["description"] as? String ?? "",
            suggestedFix: dict["suggestedFix"] as? String
        )
    }
    
    private func parseSuggestion(_ dict: [String: Any]) -> ReviewSuggestion {
        var lineRange: ClosedRange<Int>? = nil
        if let range = dict["lineRange"] as? [Int], range.count == 2 {
            lineRange = range[0]...range[1]
        }
        
        return ReviewSuggestion(
            file: dict["file"] as? String ?? "",
            lineRange: lineRange,
            title: dict["title"] as? String ?? "Suggestion",
            description: dict["description"] as? String ?? "",
            suggestedCode: dict["suggestedCode"] as? String
        )
    }
    
    private func parsePositive(_ dict: [String: Any]) -> ReviewPositive {
        return ReviewPositive(
            file: dict["file"] as? String,
            title: dict["title"] as? String ?? "Good work",
            description: dict["description"] as? String ?? ""
        )
    }
}

// MARK: - Skill Runner (Placeholder)


