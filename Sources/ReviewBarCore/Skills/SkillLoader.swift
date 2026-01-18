import Foundation
import Yams

public struct LoadedSkill: Sendable, Identifiable {
    public var id: String { content.id }
    public let sourceURL: URL
    public let content: SkillFile
    
    public init(sourceURL: URL, content: SkillFile) {
        self.sourceURL = sourceURL
        self.content = content
    }
}

public actor SkillLoader {
    private let validator: SkillValidator
    
    public init(validator: SkillValidator = SkillValidator()) {
        self.validator = validator
    }
    
    public func loadSkill(at url: URL) throws -> LoadedSkill {
        let data = try Data(contentsOf: url)
        let decoder = YAMLDecoder()
        let skillFile = try decoder.decode(SkillFile.self, from: data)
        
        try validator.validate(skillFile)
        
        return LoadedSkill(
            sourceURL: url,
            content: skillFile
        )
    }
    
    public func loadSkills(in directory: URL) async throws -> [LoadedSkill] {
        var skills: [LoadedSkill] = []
        let fileManager = FileManager.default
        
        // Ensure directory exists
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "yaml" || fileURL.pathExtension == "yml" else { continue }
            
            do {
                let skill = try loadSkill(at: fileURL)
                skills.append(skill)
            } catch {
                print("Failed to load skill at \(fileURL): \(error)")
                // Continue loading others
            }
        }
        
        return skills
    }
}
