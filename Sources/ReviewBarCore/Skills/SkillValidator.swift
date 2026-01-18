import Foundation

public enum SkillValidationError: LocalizedError {
    case duplicateRuleID(String)
    case invalidRegex(String, Error)
    case missingTriggers
    
    public var errorDescription: String? {
        switch self {
        case .duplicateRuleID(let id):
            return "Duplicate rule ID found: \(id)"
        case .invalidRegex(let pattern, let error):
            return "Invalid regex pattern '\(pattern)': \(error.localizedDescription)"
        case .missingTriggers:
            return "Skill must have at least one trigger defined"
        }
    }
}

public struct SkillValidator {
    public init() {}
    
    public func validate(_ skill: SkillFile) throws {
        // Check triggers
        if skill.triggers.isEmpty {
            throw SkillValidationError.missingTriggers
        }
        
        // Check rule IDs
        let ids = skill.rules.map { $0.id }
        if let duplicate = ids.firstDuplicate() {
            throw SkillValidationError.duplicateRuleID(duplicate)
        }
        
        // Validate regex patterns
        for rule in skill.rules {
            if let pattern = rule.pattern {
                do {
                    _ = try NSRegularExpression(pattern: pattern)
                } catch {
                    throw SkillValidationError.invalidRegex(pattern, error)
                }
            }
        }
    }
}

private extension Array where Element: Hashable {
    func firstDuplicate() -> Element? {
        var seen = Set<Element>()
        for element in self {
            if seen.contains(element) {
                return element
            }
            seen.insert(element)
        }
        return nil
    }
}
