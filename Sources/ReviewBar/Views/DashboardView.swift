import SwiftUI
import ReviewBarCore

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
        Task {
            do {
                _ = try await reviewStore.startReview(request)
            } catch {
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
    
    var body: some View {
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
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
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
                onRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
        }
        .padding()
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
        HStack(spacing: 16) {
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
                .font(.caption)
                .foregroundColor(.secondary)
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
                    .tint(.accentColor)
                    .shadow(color: .accentColor.opacity(0.3), radius: 2)
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)).animation(.snappy))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovering ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(isHovering ? 0.15 : 0.05), radius: 8, x: 0, y: isHovering ? 4 : 2)
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
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
            HStack(spacing: 16) {
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
                    
                    HStack(spacing: 12) {
                        Label(result.pullRequest.repository, systemImage: "folder")
                        Label("\(result.issues.count) issues", systemImage: "exclamationmark.circle")
                        Label(result.analyzedAt.relativeDescription ?? "Just now", systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                        .cornerRadius(6)
                    
                    Text("\(Int(result.confidence * 100))% confidence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovering ? recommendationColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(isHovering ? 0.15 : 0.05), radius: 8, x: 0, y: isHovering ? 4 : 2)
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
        }
        .buttonStyle(.plain)
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
    var body: some View {
        VStack(spacing: 20) {
            Text("Analytics")
                .font(.largeTitle.weight(.bold))
            
            Text("Coming soon!")
                .foregroundColor(.secondary)
            
            // Placeholder for future analytics
            HStack(spacing: 20) {
                AnalyticCard(
                    title: "Reviews This Week",
                    value: "12",
                    trend: "+3",
                    color: .blue
                )
                
                AnalyticCard(
                    title: "Avg Review Time",
                    value: "2.4s",
                    trend: "-0.5s",
                    color: .green
                )
                
                AnalyticCard(
                    title: "Issues Found",
                    value: "28",
                    trend: "+5",
                    color: .orange
                )
            }
            .padding()
            
            Spacer()
        }
        .padding()
    }
}

struct AnalyticCard: View {
    let title: String
    let value: String
    let trend: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
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
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(16)
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
