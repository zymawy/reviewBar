import SwiftUI
import ReviewBarCore

/// Main modal view for displaying review results
public struct ReviewModalView: View {
    let result: ReviewResult
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var reviewStore: ReviewStore
    
    @State private var selectedTab: ReviewTab = .issues
    @State private var isPosting = false
    @State private var showCopiedToast = false
    
    @State private var showPostError = false
    @State private var postErrorMessage = ""
    
    public init(result: ReviewResult) {
        self.result = result
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            ReviewHeader(result: result)
            
            Divider()
            
            // Summary Card
            SummaryCard(result: result)
                .padding()
            
            Divider()
            
            // Tab Bar
            TabBar(selectedTab: $selectedTab, result: result)
            
            Divider()
            
            // Content
            ScrollView {
                LazyVStack(spacing: 12) {
                    switch selectedTab {
                    case .issues:
                        IssuesSection(issues: result.issues)
                    case .suggestions:
                        SuggestionsSection(suggestions: result.suggestions)
                    case .positives:
                        PositivesSection(positives: result.positives)
                    case .skills:
                        SkillsSection(results: result.skillResults)
                    case .diff:
                        if let diff = result.diff {
                            DiffView(diff: diff)
                        } else {
                            EmptyStateView(icon: "doc.text", title: "No Diff Available", subtitle: "Diff content was not captured for this review.")
                        }
                    case .chat:
                        AIChatView(reviewResult: result)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Action Bar
            ActionBar(
                result: result,
                isPosting: $isPosting,
                showCopiedToast: $showCopiedToast,
                showPostError: $showPostError,
                postErrorMessage: $postErrorMessage,
                onDismiss: { dismiss() }
            )
        }
        .frame(minWidth: 600, minHeight: 500)
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                ToastView(message: "Copied to clipboard")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 60)
            }
        }
        .alert("Failed to Post", isPresented: $showPostError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(postErrorMessage)
        }
        .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
    }
}

// MARK: - Review Header

struct ReviewHeader: View {
    let result: ReviewResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Recommendation badge
            RecommendationBadge(recommendation: result.recommendation)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.pullRequest.title)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(result.pullRequest.repository)
                        .foregroundColor(.secondary)
                    
                    Text("#\(result.pullRequest.number)")
                        .foregroundColor(.secondary)
                    
                    Text("by @\(result.pullRequest.author)")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 8) {
                    Label("+\(result.pullRequest.additions)", systemImage: "plus")
                        .foregroundColor(.green)
                    
                    Label("-\(result.pullRequest.deletions)", systemImage: "minus")
                        .foregroundColor(.red)
                }
                .font(.caption)
                
                Text("\(result.pullRequest.changedFiles) files")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Recommendation Badge

struct RecommendationBadge: View {
    let recommendation: ReviewRecommendation
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            Text(recommendation.displayName)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(recommendation.color)
        .foregroundColor(.white)
        .cornerRadius(DesignSystem.Radius.small)
    }
    
    private var iconName: String {
        switch recommendation {
        case .approve: return "checkmark.circle.fill"
        case .requestChanges: return "xmark.circle.fill"
        case .comment: return "bubble.left.fill"
        }
    }
    
}

// MARK: - Summary Card

struct SummaryCard: View {
    let result: ReviewResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stats row
            HStack(spacing: 20) {
                StatItem(
                    icon: "exclamationmark.circle.fill",
                    count: result.issues.count,
                    label: "Issues",
                    color: .red
                )
                
                StatItem(
                    icon: "lightbulb.fill",
                    count: result.suggestions.count,
                    label: "Suggestions",
                    color: .yellow
                )
                
                StatItem(
                    icon: "hand.thumbsup.fill",
                    count: result.positives.count,
                    label: "Positives",
                    color: .green
                )
                
                Spacer()
                
                // Confidence
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(result.confidence * 100))%")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(confidenceColor)
                }
            }
            
            Divider()
            
            // Summary text
            Text(result.summary)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(DesignSystem.Spacing.medium)
        .glassCard()
    }
    
    private var confidenceColor: Color {
        if result.confidence >= 0.8 { return .green }
        if result.confidence >= 0.6 { return .yellow }
        return .orange
    }
}

struct StatItem: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text("\(count)")
                    .font(.title2.weight(.bold))
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Tab Bar

enum ReviewTab: String, CaseIterable {
    case issues = "Issues"
    case suggestions = "Suggestions"
    case positives = "Positives"
    case skills = "Skills"
    case diff = "Diff"
    case chat = "Ask AI"
}

struct TabBar: View {
    @Binding var selectedTab: ReviewTab
    let result: ReviewResult
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ReviewTab.allCases, id: \.self) { tab in
                TabButton(
                    title: tab.rawValue,
                    count: count(for: tab),
                    isSelected: selectedTab == tab
                ) {
                    selectedTab = tab
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func count(for tab: ReviewTab) -> Int {
        switch tab {
        case .issues: return result.issues.count
        case .suggestions: return result.suggestions.count
        case .positives: return result.positives.count
        case .skills: return result.skillResults.count
        case .diff: return 0 // No count for diff
        case .chat: return 0 // No count for chat
        }
    }
}

struct TabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.accentColor : Color.gray.opacity(0.3))
                        .foregroundColor(isSelected ? .white : .primary)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(DesignSystem.Radius.small)
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? DesignSystem.Colors.brandPrimary : .secondary)
    }
}

// MARK: - Content Sections

struct IssuesSection: View {
    let issues: [ReviewIssue]
    
    var body: some View {
        if issues.isEmpty {
            EmptyStateView(
                icon: "checkmark.circle",
                title: "No Issues Found",
                subtitle: "Great job! No issues were detected in this PR."
            )
        } else {
            ForEach(issues) { issue in
                IssueRow(issue: issue)
            }
        }
    }
}

struct IssueRow: View {
    let issue: ReviewIssue
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                SeverityBadge(severity: issue.severity)
                
                CategoryBadge(category: issue.category)
                
                Spacer()
                
                if let range = issue.lineRange {
                    Text("L\(range.lowerBound)-\(range.upperBound)")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }
            
            // Title
            Text(issue.title)
                .font(.headline)
            
            // File
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                Text(issue.file)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
            
            // Description
            Text(issue.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            // Suggested fix (expandable)
            if let fix = issue.suggestedFix {
                DisclosureGroup("Suggested Fix", isExpanded: $isExpanded) {
                    Text(fix)
                        .font(.system(.caption, design: .monospaced))
                        .padding(DesignSystem.Radius.small)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(DesignSystem.Radius.small)
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .glassCard()
    }
}

struct SeverityBadge: View {
    let severity: IssueSeverity
    
    var body: some View {
        Text(severity.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(DesignSystem.Radius.small)
    }
    
    private var color: Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

struct CategoryBadge: View {
    let category: IssueCategory
    
    var body: some View {
        Text(category.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(DesignSystem.Radius.small)
    }
}

struct SuggestionsSection: View {
    let suggestions: [ReviewSuggestion]
    
    var body: some View {
        if suggestions.isEmpty {
            EmptyStateView(
                icon: "lightbulb",
                title: "No Suggestions",
                subtitle: "No improvement suggestions at this time."
            )
        } else {
            ForEach(suggestions) { suggestion in
                SuggestionRow(suggestion: suggestion)
            }
        }
    }
}

struct SuggestionRow: View {
    let suggestion: ReviewSuggestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(suggestion.title)
                .font(.headline)
            
            if !suggestion.file.isEmpty {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                    Text(suggestion.file)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }
            
            Text(suggestion.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            if let code = suggestion.suggestedCode {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .padding(DesignSystem.Radius.small)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(DesignSystem.Radius.small)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .glassCard()
    }
}

struct PositivesSection: View {
    let positives: [ReviewPositive]
    
    var body: some View {
        if positives.isEmpty {
            EmptyStateView(
                icon: "hand.thumbsup",
                title: "No Positives Noted",
                subtitle: "No specific positives were highlighted."
            )
        } else {
            ForEach(positives) { positive in
                PositiveRow(positive: positive)
            }
        }
    }
}

struct PositiveRow: View {
    let positive: ReviewPositive
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.thumbsup.fill")
                .foregroundColor(.green)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(positive.title)
                    .font(.headline)
                
                Text(positive.description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .glassCard(tintColor: .green)
    }
}

struct SkillsSection: View {
    let results: [SkillResult]
    
    var body: some View {
        if results.isEmpty {
            EmptyStateView(
                icon: "wand.and.stars",
                title: "No Skills Applied",
                subtitle: "No custom skills were run for this review."
            )
        } else {
            ForEach(results) { result in
                SkillResultRow(result: result)
            }
        }
    }
}

struct SkillResultRow: View {
    let result: SkillResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.passed ? .green : .red)
                
                Text(result.skillName)
                    .font(.headline)
                
                Spacer()
                
                Text(String(format: "%.2fs", result.executionTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !result.findings.isEmpty {
                ForEach(result.findings.indices, id: \.self) { index in
                    let finding = result.findings[index]
                    HStack {
                        Text(finding.severity.emoji)
                        Text(finding.message)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .glassCard()
    }
}

// MARK: - Action Bar

struct ActionBar: View {
    let result: ReviewResult
    @Binding var isPosting: Bool
    @Binding var showCopiedToast: Bool
    @Binding var showPostError: Bool
    @Binding var postErrorMessage: String
    @EnvironmentObject var reviewStore: ReviewStore
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            // Duration info
            Text("Analyzed in \(String(format: "%.1fs", result.duration))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Actions
            Button("Copy") {
                copyToClipboard()
            }
            .keyboardShortcut("c", modifiers: .command)
            
            Button("Open in Browser") {
                NSWorkspace.shared.open(result.pullRequest.url)
            }
            
            Button("Post to GitHub") {
                Task {
                    await postReview()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPosting)
            
            Button("Dismiss") {
                onDismiss()
            }
        }
        .padding()
    }
    
    private func copyToClipboard() {
        let text = formatReviewAsMarkdown()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }
    
    private func formatReviewAsMarkdown() -> String {
        var md = "## Code Review: \(result.pullRequest.title)\n\n"
        md += "**Recommendation:** \(result.recommendation.emoji) \(result.recommendation.displayName)\n\n"
        md += "### Summary\n\n\(result.summary)\n\n"
        
        if !result.issues.isEmpty {
            md += "### Issues (\(result.issues.count))\n\n"
            for issue in result.issues {
                md += "- \(issue.severity.emoji) **\(issue.title)** (\(issue.file))\n"
                md += "  \(issue.description)\n\n"
            }
        }
        
        if !result.suggestions.isEmpty {
            md += "### Suggestions (\(result.suggestions.count))\n\n"
            for suggestion in result.suggestions {
                md += "- 💡 **\(suggestion.title)**\n"
                md += "  \(suggestion.description)\n\n"
            }
        }
        
        if !result.positives.isEmpty {
            md += "### What's Good (\(result.positives.count))\n\n"
            for positive in result.positives {
                md += "- ✅ **\(positive.title)**\n"
                md += "  \(positive.description)\n\n"
            }
        }
        
        md += "\n---\n*Generated by ReviewBar*"
        
        return md
    }
    
    private func postReview() async {
        isPosting = true
        defer { isPosting = false }
        
        do {
            try await reviewStore.postReview(result)
            onDismiss()
        } catch {
            postErrorMessage = error.localizedDescription
            showPostError = true
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Toast

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(radius: 5)
    }
}

// MARK: - Extensions

extension ReviewRecommendation {
    var color: Color {
        switch self {
        case .approve: return .green
        case .requestChanges: return .red
        case .comment: return .blue
        }
    }
}

extension Date {
    var relativeDescription: String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
