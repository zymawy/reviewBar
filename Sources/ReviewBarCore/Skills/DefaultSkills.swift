import Foundation

public enum DefaultSkills {
    public static func install(to directory: URL) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        let skills: [String: String] = [
            "security.yaml": securitySkill,
            "swift-best-practices.yaml": swiftBestPracticesSkill
        ]
        
        for (filename, content) in skills {
            let fileURL = directory.appendingPathComponent(filename)
            if !fileManager.fileExists(atPath: fileURL.path) {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private static let securitySkill = """
name: security-audit
version: 1.0.0
description: Basic security checks for common vulnerabilities

triggers:
  - file_extension: [".swift", ".js", ".ts", ".py", ".go", ".java"]

rules:
  - id: hardcoded-credentials
    severity: critical
    pattern: "(?i)(password|secret|api_key|access_token|auth_token)\\\\s*[:=]\\\\s*['\\"][a-zA-Z0-9_\\\\-]{8,}['\\"]"
    message: "Potential hardcoded credential found. Use environment variables or a secrets manager."

  - id: unsafe-eval
    severity: critical
    pattern: "eval\\\\("
    message: "Avoid using eval() as it poses security risks."

  - id: no-http-urls
    severity: warning
    pattern: "http://(?!localhost)"
    message: "Use HTTPS instead of HTTP for secure communication."

prompts:
  additional_context: |
    Pay special attention to data validation and sanitization.
    Ensure no sensitive data is logged in plain text.
"""

    private static let swiftBestPracticesSkill = """
name: swift-best-practices
version: 1.0.0
description: Enforce Swift coding conventions and best practices

triggers:
  - file_extension: [".swift"]

rules:
  - id: force-unwrapping
    severity: warning
    pattern: "[^?]!\\\\s"
    message: "Avoid force unwrapping optionals. Use if-let, guard-let, or nil-coalescing ?? instead."

  - id: todo-markers
    severity: info
    pattern: "(?i)//\\\\s*TODO:|//\\\\s*FIXME:"
    message: "Ensure TODOs have tracking tickets or are resolved before merging."

  - id: print-debugging
    severity: info
    pattern: "print\\\\("
    message: "Remove debug print statements or use a logger."

prompts:
  additional_context: |
    Follow the Swift API Design Guidelines.
    Prefer value types (structs) over reference types (classes) where appropriate.
    Use protocol-oriented programming.
"""
}
