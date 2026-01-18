import SwiftUI

/// Design system constants and components for ReviewBar
public enum DesignSystem {
    
    // MARK: - Colors
    
    public enum Colors {
        // App Core
        public static let brandPrimary = Color.blue
        public static let brandSecondary = Color.purple
        
        // Semantic Review States
        public static let approve = Color.green
        public static let requestChanges = Color.red
        public static let comment = Color.blue
        
        // Gradients
        public static let brandGradient = LinearGradient(
            colors: [brandPrimary, brandSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let approveGradient = LinearGradient(
            colors: [approve, approve.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        public static let warningGradient = LinearGradient(
            colors: [Color.orange, Color.red],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Surface Colors
        public static let cardBackground = Color(nsColor: .controlBackgroundColor).opacity(0.6)
        public static let sidebarBackground = Color(nsColor: .windowBackgroundColor).opacity(0.4)
    }
    
    // MARK: - Spacing
    
    public enum Spacing {
        public static let tint: CGFloat = 4
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 24
        public static let extraLarge: CGFloat = 32
    }
    
    // MARK: - Radius
    
    public enum Radius {
        public static let small: CGFloat = 6
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let full: CGFloat = 999
    }
}

// MARK: - View Modifiers

public struct GlassCard: ViewModifier {
    var isHovered: Bool
    var tintColor: Color?
    
    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(tintColor?.opacity(0.05) ?? Color.clear)
            .cornerRadius(DesignSystem.Radius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                    .stroke(isHovered ? (tintColor?.opacity(0.5) ?? Color.accentColor.opacity(0.3)) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 12 : 8, x: 0, y: isHovered ? 6 : 2)
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

public extension View {
    func glassCard(isHovered: Bool = false, tintColor: Color? = nil) -> some View {
        modifier(GlassCard(isHovered: isHovered, tintColor: tintColor))
    }
    
    func brandTitle() -> some View {
        self.font(.system(.title, design: .rounded).weight(.bold))
    }
    
    func brandSecondary() -> some View {
        self.font(.subheadline)
            .foregroundColor(.secondary)
    }
}

// MARK: - Reusable Components

public struct BrandIcon: View {
    let icon: String
    let gradient: LinearGradient
    var size: CGFloat = 48
    
    public init(icon: String, gradient: LinearGradient = DesignSystem.Colors.brandGradient, size: CGFloat = 48) {
        self.icon = icon
        self.gradient = gradient
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .fill(gradient)
                .frame(width: size, height: size)
                .opacity(0.1)
            
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.6, height: size * 0.6)
                .foregroundStyle(gradient)
        }
    }
}
