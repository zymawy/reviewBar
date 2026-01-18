import SwiftUI
import ReviewBarCore
import Charts

/// Dashboard view showing all pending reviews and recent activity
struct DashboardView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var reviewStore: ReviewStore
    
    @State private var selectedTab: DashboardTab = .pending
    @State private var searchText = ""
    @State private var filterRepository: String?
    @State private var sortOrder: SortOrder = .newest
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedTab) {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.title, systemImage: tab.icon)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
            
        } detail: {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                
                VStack(spacing: 0) {
                    // Status Banner
                    if reviewStore.isReviewing {
                        HStack(spacing: 12) {
                            ProgressView().scaleEffect(0.6)
                            Text(reviewStore.statusMessage)
                                .font(.callout.weight(.medium))
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                        .overlay(Divider(), alignment: .bottom)
                    }
                    
                    // Toolbar area
                    DashboardToolbar(
                        searchText: $searchText,
                        filterRepository: $filterRepository,
                        sortOrder: $sortOrder,
                        onRefresh: { Task { await reviewStore.refresh() } }
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.regularMaterial)
                    .overlay(Divider(), alignment: .bottom)
                    
                    // Main Content
                    switch selectedTab {
                    case .pending:
                        PendingReviewsView(
                            reviews: filteredPendingReviews,
                            onStartReview: startReview,
                            onDismiss: dismissReview
                        )
                    case .recent:
                        RecentResultsView(results: reviewStore.recentResults)
                    case .analytics:
                        AnalyticsView()
                    case .logs:
                        ActivityLogsView(logs: reviewStore.activityLog)
                    }
                }
            }
            .background(.thickMaterial)
        }
        .alert(item: Binding<ErrorWrapper?>(
            get: { reviewStore.lastError.map { ErrorWrapper(error: $0) } },
            set: { _ in reviewStore.clearError() }
        )) { wrapper in
            Alert(
                title: Text("Error"),
                message: Text(wrapper.error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    
    private var filteredPendingReviews: [ReviewRequest] {
        var reviews = reviewStore.pendingReviews
        
        // Search filter
        if !searchText.isEmpty {
            reviews = reviews.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.repository.fullName.localizedCaseInsensitiveContains(searchText) ||
                $0.author.login.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Repository filter
        if let repo = filterRepository {
            reviews = reviews.filter { $0.repository.fullName == repo }
        }
        
        // Sort
        switch sortOrder {
        case .newest:
            reviews.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            reviews.sort { $0.createdAt < $1.createdAt }
        case .priority:
            reviews.sort { $0.priority > $1.priority }
        case .repository:
            reviews.sort { $0.repository.fullName < $1.repository.fullName }
        }
        
        return reviews
    }
    
    private func startReview(_ request: ReviewRequest) {
        HapticManager.trigger(.generic)
        Task {
            do {
                _ = try await reviewStore.startReview(request)
            } catch {
                HapticManager.error()
                print("Failed to start review: \(error)")
            }
        }
    }
    
    private func dismissReview(_ request: ReviewRequest) {
        reviewStore.dismissPendingReview(request)
    }
}

enum DashboardTab: CaseIterable {
    case pending
    case recent
    case analytics
    case logs
    
    var title: String {
        switch self {
        case .pending: return "Pending Reviews"
        case .recent: return "Recent Activity"
        case .analytics: return "Analytics"
        case .logs: return "Activity Logs"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .recent: return "checkmark.circle"
        case .analytics: return "chart.bar"
        case .logs: return "terminal"
        }
    }
}

enum SortOrder: String, CaseIterable {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case priority = "Priority"
    case repository = "Repository"
}

// MARK: - Toolbar

struct DashboardToolbar: View {
    @Binding var searchText: String
    @Binding var filterRepository: String?
    @Binding var sortOrder: SortOrder
    let onRefresh: () -> Void
    @EnvironmentObject var reviewStore: ReviewStore
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search PRs...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(DesignSystem.Radius.small)
                .frame(maxWidth: 300)
                
                Spacer()
                
                // Sort
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .frame(width: 150)
                
                // Refresh
                Button {
                    HapticManager.trigger(.generic)
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            .padding()
            
            if reviewStore.isReviewing {
                ReviewProgressBar()
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

struct ReviewProgressBar: View {
    @State private var progress: Double = 0.3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Analyzing codebase...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(DesignSystem.Colors.brandPrimary)
        }
        .padding(8)
        .background(DesignSystem.Colors.brandPrimary.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.small)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever()) {
                progress = 0.9
            }
        }
    }
}

// MARK: - Pending Reviews View

struct PendingReviewsView: View {
    let reviews: [ReviewRequest]
    let onStartReview: (ReviewRequest) -> Void
    let onDismiss: (ReviewRequest) -> Void
    
    var body: some View {
        if reviews.isEmpty {
            EmptyStateView(
                icon: "checkmark.circle",
                title: "No Pending Reviews",
                subtitle: "You're all caught up! No PRs are waiting for your review."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(reviews) { request in
                        PendingReviewCard(
                            request: request,
                            onStartReview: { onStartReview(request) },
                            onDismiss: { onDismiss(request) }
                        )
                    }
                }
                .padding()
            }
        }
    }
}

struct PendingReviewCard: View {
    let request: ReviewRequest
    let onStartReview: () -> Void
    let onDismiss: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            // Priority indicator with glow
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
                .shadow(color: priorityColor.opacity(0.6), radius: 4, x: 0, y: 0)
                .padding(.leading, 4)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(request.title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Label(request.repository.fullName, systemImage: "folder")
                    Label("#\(request.number)", systemImage: "number")
                    Label("@\(request.author.login)", systemImage: "person")
                    Label(request.createdAt.relativeDescription ?? "Unknown", systemImage: "clock")
                }
                .brandSecondary()
                .symbolRenderingMode(.hierarchical)
            }
            
            Spacer()
            
            // Actions
            if isHovering {
                HStack(spacing: 8) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                    
                    Button("Review") {
                        onStartReview()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignSystem.Colors.brandPrimary)
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)).animation(.snappy))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.medium - 4)
        .glassCard(isHovered: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private var priorityColor: Color {
        switch request.priority {
        case .critical: return .red
        case .high: return .orange
        case .normal: return .blue
        case .low: return .gray
        }
    }
}

// MARK: - Recent Results View

struct RecentResultsView: View {
    let results: [ReviewResult]
    
    var body: some View {
        if results.isEmpty {
            EmptyStateView(
                icon: "clock",
                title: "No Recent Reviews",
                subtitle: "Reviews you complete will appear here."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(results) { result in
                        RecentResultCard(result: result)
                    }
                }
                .padding()
            }
        }
    }
}

struct RecentResultCard: View {
    let result: ReviewResult
    @State private var showModal = false
    @State private var isHovering = false
    
    var body: some View {
        Button {
            showModal = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.medium) {
                // Recommendation badge with glow
                Image(systemName: recommendationIcon)
                    .font(.title2)
                    .foregroundColor(recommendationColor)
                    .frame(width: 32)
                    .shadow(color: recommendationColor.opacity(0.4), radius: 6)
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.pullRequest.title)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: DesignSystem.Spacing.small) {
                        Label(result.pullRequest.repository, systemImage: "folder")
                        Label("\(result.issues.count) issues", systemImage: "exclamationmark.circle")
                        Label(result.analyzedAt.relativeDescription ?? "Just now", systemImage: "clock")
                    }
                    .brandSecondary()
                    .symbolRenderingMode(.hierarchical)
                }
                
                Spacer()
                
                // Stats
                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.recommendation.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(recommendationColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(recommendationColor.opacity(0.1))
                        .cornerRadius(DesignSystem.Radius.small)
                    
                    Text("\(Int(result.confidence * 100))% confidence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.medium - 4)
            .glassCard(isHovered: isHovering, tintColor: recommendationColor)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .sheet(isPresented: $showModal) {
            ReviewModalView(result: result)
        }
    }
    
    private var recommendationIcon: String {
        switch result.recommendation {
        case .approve: return "checkmark.circle.fill"
        case .requestChanges: return "xmark.circle.fill"
        case .comment: return "bubble.left.fill"
        }
    }
    
    private var recommendationColor: Color {
        result.recommendation.color
    }
}

// MARK: - Analytics View

struct AnalyticsView: View {
    @StateObject private var analytics = AnalyticsService.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                Text("Performance Overview")
                    .brandTitle()
                
                // Top Metrics
                HStack(spacing: DesignSystem.Spacing.medium) {
                    AnalyticCard(title: "Total Reviews", value: "\(analytics.totalReviews)", trend: "+12%", color: .blue)
                    AnalyticCard(title: "Avg Confidence", value: "\(Int(analytics.averageConfidence * 100))%", trend: "+5%", color: .green)
                    AnalyticCard(title: "Issues Found", value: "\(analytics.totalIssuesFound)", trend: "-8%", color: .orange)
                }
                
                // Review Activity Chart
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    Text("Review Activity")
                        .font(.headline)
                    
                    if analytics.chartData.isEmpty {
                        EmptyStateView(icon: "chart.bar", title: "No Data Yet", subtitle: "Review activity will appear here once you start analyzing PRs.")
                            .frame(height: 200)
                    } else {
                        Chart(analytics.chartData) { item in
                            BarMark(
                                x: .value("Date", item.date, unit: .day),
                                y: .value("Count", item.count)
                            )
                            .foregroundStyle(DesignSystem.Colors.brandGradient)
                            .cornerRadius(DesignSystem.Radius.small)
                        }
                        .frame(height: 200)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.day().month())
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.medium)
                .glassCard()
                
                // Issues by Category (Placeholder for now)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                    Text("Top Issue Categories")
                        .font(.headline)
                    
                    Chart {
                        BarMark(x: .value("Category", "Security"), y: .value("Count", 5))
                            .foregroundStyle(.red.gradient)
                        BarMark(x: .value("Category", "Logic"), y: .value("Count", 12))
                            .foregroundStyle(.orange.gradient)
                        BarMark(x: .value("Category", "Style"), y: .value("Count", 8))
                            .foregroundStyle(.blue.gradient)
                        BarMark(x: .value("Category", "Performance"), y: .value("Count", 3))
                            .foregroundStyle(.green.gradient)
                    }
                    .frame(height: 150)
                }
                .padding(DesignSystem.Spacing.medium)
                .glassCard()
            }
            .padding()
        }
    }
}

struct AnalyticCard: View {
    let title: String
    let value: String
    let trend: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(trend)
                .font(.caption.weight(.semibold))
                .foregroundColor(trend.hasPrefix("-") ? .green : .orange)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.medium)
        .background(color.opacity(0.1))
        .cornerRadius(DesignSystem.Radius.medium)
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(SettingsStore())
        .environmentObject(ReviewStore())
}

struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: Error
}

// MARK: - Activity Logs View

struct ActivityLogsView: View {
    let logs: [ReviewStore.LogEntry]
    
    var body: some View {
        if logs.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No activity yet")
                    .font(.headline)
                Text("Logs will appear here when you start reviewing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(logs) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(entry.level.rawValue)
                            
                            Text(entry.timestamp, style: .time)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                            
                            Text(entry.message)
                                .font(.callout)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical)
            }
        }
    }
}
