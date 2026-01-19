import Foundation

public struct ReviewProfile: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var systemPrompt: String
    public var isDefault: Bool
    
    public init(id: UUID = UUID(), name: String, icon: String, systemPrompt: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.systemPrompt = systemPrompt
        self.isDefault = isDefault
    }
    
    public static let standard = ReviewProfile(
        name: "Standard",
        icon: "checkmark.circle",
        systemPrompt: "You are an expert code reviewer. Analyze the code for bugs, security issues, and style violations.",
        isDefault: true
    )
    
    public static let security = ReviewProfile(
        name: "Security Auditer",
        icon: "lock.shield",
        systemPrompt: "You are a security expert. Focus ONLY on potential security vulnerabilities, injections, and data leaks.",
        isDefault: false
    )
    
    public static let performance = ReviewProfile(
        name: "Performance Sniper",
        icon: "speedometer",
        systemPrompt: "You are a performance engineer. Focus on O(n) complexity, memory leaks, and expensive operations.",
        isDefault: false
    )
}
