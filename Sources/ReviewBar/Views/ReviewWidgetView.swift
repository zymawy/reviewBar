import SwiftUI
import ReviewBarCore

public struct ReviewWidgetView: View {
    public let pendingCount: Int
    public let urgentCount: Int
    
    public init(pendingCount: Int, urgentCount: Int) {
        self.pendingCount = pendingCount
        self.urgentCount = urgentCount
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(DesignSystem.Colors.brandGradient)
                
                Spacer()
                
                Text("\(pendingCount)")
                    .font(.system(.title, design: .rounded).weight(.bold))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Pending Reviews")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
                if urgentCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        Text("\(urgentCount) Urgent")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.Radius.medium)
    }
}

#Preview("Widget Preview") {
    ReviewWidgetView(pendingCount: 12, urgentCount: 3)
        .frame(width: 170, height: 170)
}
