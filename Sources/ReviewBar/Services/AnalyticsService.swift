import Foundation
import ReviewBarCore

public final class AnalyticsService: ObservableObject {
    public static let shared = AnalyticsService()
    
    @Published public var history: [ReviewResult] = []
    
    private init() {
        // In a real app, this would load from disk
    }
    
    public func track(result: ReviewResult) {
        history.append(result)
        // Save to disk...
    }
    
    // MARK: - Stats
    
    public var totalReviews: Int {
        history.count
    }
    
    public var averageConfidence: Double {
        guard !history.isEmpty else { return 0 }
        return history.reduce(0) { $0 + $1.confidence } / Double(history.count)
    }
    
    public var totalIssuesFound: Int {
        history.reduce(0) { $0 + $1.issues.count }
    }
    
    public var reviewsByDay: [Date: Int] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        
        for result in history {
            let date = calendar.startOfDay(for: result.analyzedAt)
            counts[date, default: 0] += 1
        }
        
        return counts
    }
    
    public struct ChartData: Identifiable {
        public let id = UUID()
        public let date: Date
        public let count: Int
    }
    
    public var chartData: [ChartData] {
        reviewsByDay.map { ChartData(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }
    }
}
