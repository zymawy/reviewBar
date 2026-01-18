import Foundation

public actor MCPBridge {
    private let loader: SkillLoader
    private let skillsDirectory: URL
    
    public init(loader: SkillLoader = SkillLoader(), skillsDirectory: URL? = nil) {
        self.loader = loader
        if let directory = skillsDirectory {
            self.skillsDirectory = directory
        } else {
            self.skillsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("ReviewBar/skills")
        }
    }
    
    public func executeSkills(
        diff: ParsedDiff,
        skillIDs: [String]
    ) async -> [SkillResult] {
        // Load skills if IDs provided
        guard !skillIDs.isEmpty else { return [] }
        
        guard let allSkills = try? await loader.loadSkills(in: skillsDirectory) else {
            return []
        }
        
        // Filter requested skills
        let targetSkills = allSkills.filter { skillIDs.contains($0.id) }
        
        var results: [SkillResult] = []
        
        for skill in targetSkills {
            let result = await executeSkill(skill, on: diff)
            results.append(result)
        }
        
        return results
    }
    
    private func executeSkill(_ skill: LoadedSkill, on diff: ParsedDiff) async -> SkillResult {
        let startTime = Date()
        var findings: [SkillFinding] = []
        
        // 1. Check triggers
        if !shouldRun(skill.content, on: diff) {
            return SkillResult(
                skillName: skill.content.name,
                passed: true,
                findings: [],
                executionTime: 0
            )
        }
        
        // 2. Execute rules
        for rule in skill.content.rules {
            // Regex based check
            if let pattern = rule.pattern {
                let ruleFindings = checkRegexRule(pattern, rule: rule, diff: diff)
                findings.append(contentsOf: ruleFindings)
            }
            
            // TODO: Implement MCP check execution (call external tool)
            if rule.check != nil {
                // For now, checks are just prompts passed to LLM later, no local execution
                // We could implement basic validation here if needed
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return SkillResult(
            skillName: skill.content.name,
            passed: findings.isEmpty,
            findings: findings,
            executionTime: duration
        )
    }
    
    private func shouldRun(_ skill: SkillFile, on diff: ParsedDiff) -> Bool {
        // Run if ANY trigger matches
        for trigger in skill.triggers {
            // Check file extensions
            if let extensions = trigger.fileExtensions {
                let hasMatchingExtension = diff.files.contains { file in
                    let url = URL(fileURLWithPath: file.path)
                    return extensions.contains { $0.lowercased().hasSuffix(url.pathExtension.lowercased()) || $0.lowercased() == url.pathExtension.lowercased() }
                }
                if hasMatchingExtension { return true }
            }
            
            // Check path contains
            if let paths = trigger.pathContains {
                let hasMatchingPath = diff.files.contains { file in
                    paths.contains { file.path.contains($0) }
                }
                if hasMatchingPath { return true }
            }
        }
        return false
    }
    
    private func checkRegexRule(_ pattern: String, rule: SkillRule, diff: ParsedDiff) -> [SkillFinding] {
        var findings: [SkillFinding] = []
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        
        for file in diff.files {
            for hunk in file.hunks {
                var currentLineNumber = hunk.newStart
                
                for line in hunk.lines {
                    // Only check added lines
                    if line.type == .addition {
                        let range = NSRange(line.content.startIndex..<line.content.endIndex, in: line.content)
                        if regex.firstMatch(in: line.content, range: range) != nil {
                            findings.append(SkillFinding(
                                ruleID: rule.id,
                                message: rule.message,
                                file: file.path,
                                line: currentLineNumber,
                                severity: rule.severity
                            ))
                        }
                        currentLineNumber += 1
                    } else if line.type == .context {
                        currentLineNumber += 1
                    }
                    // deletions don't advance new line number
                }
            }
        }
        
        return findings
    }
}
