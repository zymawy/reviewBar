import Foundation
import Yams

/// Represents a skill defined in a YAML file
public struct SkillFile: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let version: String
    public let description: String
    public let triggers: [SkillTrigger]
    public let rules: [SkillRule]
    public let prompts: SkillPrompts?
    
    public init(name: String, version: String, description: String, triggers: [SkillTrigger], rules: [SkillRule], prompts: SkillPrompts? = nil) {
        self.name = name
        self.version = version
        self.description = description
        self.triggers = triggers
        self.rules = rules
        self.prompts = prompts
    }
}

public struct SkillTrigger: Codable, Sendable {
    public let fileExtensions: [String]?
    public let pathContains: [String]?
    
    enum CodingKeys: String, CodingKey {
        case fileExtensions = "file_extension"
        case pathContains = "path_contains"
    }
    
    public init(fileExtensions: [String]? = nil, pathContains: [String]? = nil) {
        self.fileExtensions = fileExtensions
        self.pathContains = pathContains
    }
}

public struct SkillRule: Codable, Sendable, Identifiable {
    public let id: String
    public let severity: IssueSeverity
    public let pattern: String?
    public let check: String?
    public let message: String
    
    public init(id: String, severity: IssueSeverity, pattern: String? = nil, check: String? = nil, message: String) {
        self.id = id
        self.severity = severity
        self.pattern = pattern
        self.check = check
        self.message = message
    }
}

public struct SkillPrompts: Codable, Sendable {
    public let additionalContext: String?
    
    enum CodingKeys: String, CodingKey {
        case additionalContext = "additional_context"
    }
    
    public init(additionalContext: String?) {
        self.additionalContext = additionalContext
    }
}
