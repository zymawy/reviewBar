import SwiftUI
import ReviewBarCore

struct MenuPopoverView: View {
    @EnvironmentObject var reviewStore: ReviewStore
    @EnvironmentObject var settingsStore: SettingsStore
    
    var onShowDashboard: () -> Void
    var onShowSettings: () -> Void
    var onQuit: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.medium) {
                    statusOverview
                    
                    prioritySection
                    
                    recentSection
                }
                .padding()
            }
            .frame(maxHeight: 400)
            
            Divider()
            
            footer
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }
    
    private var header: some View {
        HStack {
            BrandIcon(icon: "shield.lefthalf.filled", size: 24)
            
            Text("ReviewBar")
                .font(.headline)
            
            Spacer()
            
            Button(action: onShowSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding()
    }
    
    private var statusOverview: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            StatusPill(
                count: reviewStore.pendingReviews.count,
                label: "Pending",
                color: .orange
            )
            
            StatusPill(
                count: reviewStore.recentResults.count,
                label: "Today",
                color: .green
            )
        }
    }
    
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Text("PRIORITY")
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
            
            if reviewStore.pendingReviews.isEmpty {
                Text("No pending reviews")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(reviewStore.pendingReviews.prefix(2)) { request in
                    PopoverReviewCard(request: request) {
                        onShowDashboard()
                    }
                }
            }
        }
    }
    
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Text("RECENT")
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
            
            if reviewStore.recentResults.isEmpty {
                Text("No recent activity")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(reviewStore.recentResults.prefix(3)) { result in
                    HStack(spacing: 8) {
                        Image(systemName: result.recommendation.icon)
                            .foregroundColor(result.recommendation.color)
                        
                        Text(result.pullRequest.title)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(result.analyzedAt.relativeDescription ?? "")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var footer: some View {
        HStack {
            Button("Open Dashboard") {
                onShowDashboard()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            
            Spacer()
            
            Button(action: { Task { await reviewStore.refresh() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh")
            
            Button("Quit", action: onQuit)
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct StatusPill: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text("\(count)")
                .font(.headline)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(DesignSystem.Radius.medium)
    }
}

struct PopoverReviewCard: View {
    let request: ReviewRequest
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(request.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                
                HStack {
                    Text(request.repository.name)
                    Text("·")
                    Text("#\(request.number)")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(DesignSystem.Radius.small)
        }
        .buttonStyle(.plain)
    }
}

extension ReviewRecommendation {
    var icon: String {
        switch self {
        case .approve: return "checkmark.circle.fill"
        case .requestChanges: return "xmark.circle.fill"
        case .comment: return "bubble.left.fill"
        }
    }
}
