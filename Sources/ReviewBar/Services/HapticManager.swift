import AppKit

public struct HapticManager {
    public static func trigger(_ type: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(type, performanceTime: .now)
    }
    
    public static func success() {
        trigger(.generic)
    }
    
    public static func error() {
        // Repeated generic for error feel
        trigger(.generic)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            trigger(.generic)
        }
    }
}
