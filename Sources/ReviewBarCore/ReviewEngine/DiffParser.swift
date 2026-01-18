import Foundation

/// Parses unified diff format into structured data
public struct DiffParser: Sendable {
    
    public init() {}
    
    /// Parse a unified diff string into structured format
    public func parse(_ diffText: String) -> ParsedDiff {
        var files: [DiffFile] = []
        var currentFile: DiffFile?
        var currentHunk: DiffHunk?
        var currentLines: [DiffLine] = []
        
        let lines = diffText.components(separatedBy: .newlines)
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            
            // New file header
            if line.hasPrefix("diff --git") {
                // Save previous file
                if var file = currentFile {
                    if var hunk = currentHunk {
                        hunk.lines = currentLines
                        file.hunks.append(hunk)
                    }
                    files.append(file)
                }
                
                currentFile = nil
                currentHunk = nil
                currentLines = []
                
                // Parse file paths from the header
                // Format: diff --git a/path/to/file b/path/to/file
                if let match = line.range(of: "b/", options: .backwards) {
                    let path = String(line[match.upperBound...])
                    currentFile = DiffFile(path: path, status: .modified, hunks: [])
                }
                
                i += 1
                continue
            }
            
            // File status indicators
            if line.hasPrefix("new file mode") {
                currentFile?.status = .added
                i += 1
                continue
            }
            
            if line.hasPrefix("deleted file mode") {
                currentFile?.status = .deleted
                i += 1
                continue
            }
            
            if line.hasPrefix("rename from") {
                currentFile?.status = .renamed
                i += 1
                continue
            }
            
            // Skip index, ---, +++ lines
            if line.hasPrefix("index ") || line.hasPrefix("---") || line.hasPrefix("+++") {
                i += 1
                continue
            }
            
            // Hunk header
            if line.hasPrefix("@@") {
                // Save previous hunk
                if var hunk = currentHunk {
                    hunk.lines = currentLines
                    currentFile?.hunks.append(hunk)
                }
                currentLines = []
                
                // Parse hunk header: @@ -start,count +start,count @@
                if let hunk = parseHunkHeader(line) {
                    currentHunk = hunk
                }
                
                i += 1
                continue
            }
            
            // Diff lines
            if currentHunk != nil {
                if line.hasPrefix("+") && !line.hasPrefix("+++") {
                    currentLines.append(DiffLine(type: .addition, content: String(line.dropFirst())))
                } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                    currentLines.append(DiffLine(type: .deletion, content: String(line.dropFirst())))
                } else if line.hasPrefix(" ") {
                    currentLines.append(DiffLine(type: .context, content: String(line.dropFirst())))
                } else if line.hasPrefix("\\") {
                    // "\ No newline at end of file" - skip
                } else if !line.isEmpty {
                    currentLines.append(DiffLine(type: .context, content: line))
                }
            }
            
            i += 1
        }
        
        // Save last file
        if var file = currentFile {
            if var hunk = currentHunk {
                hunk.lines = currentLines
                file.hunks.append(hunk)
            }
            files.append(file)
        }
        
        // Detect languages
        files = files.map { file in
            var file = file
            file.language = detectLanguage(for: file.path)
            return file
        }
        
        return ParsedDiff(files: files)
    }
    
    private func parseHunkHeader(_ line: String) -> DiffHunk? {
        // Format: @@ -start,count +start,count @@ optional context
        let pattern = #"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }
        
        func capture(_ index: Int) -> Int? {
            guard let range = Range(match.range(at: index), in: line) else { return nil }
            return Int(line[range])
        }
        
        let oldStart = capture(1) ?? 1
        let oldCount = capture(2) ?? 1
        let newStart = capture(3) ?? 1
        let newCount = capture(4) ?? 1
        
        return DiffHunk(
            oldStart: oldStart,
            oldCount: oldCount,
            newStart: newStart,
            newCount: newCount,
            lines: []
        )
    }
    
    private func detectLanguage(for path: String) -> String? {
        let ext = (path as NSString).pathExtension.lowercased()
        
        let languageMap: [String: String] = [
            "swift": "Swift",
            "ts": "TypeScript",
            "tsx": "TypeScript",
            "js": "JavaScript",
            "jsx": "JavaScript",
            "py": "Python",
            "rb": "Ruby",
            "go": "Go",
            "rs": "Rust",
            "java": "Java",
            "kt": "Kotlin",
            "kts": "Kotlin",
            "scala": "Scala",
            "c": "C",
            "h": "C",
            "cpp": "C++",
            "cc": "C++",
            "hpp": "C++",
            "cs": "C#",
            "m": "Objective-C",
            "mm": "Objective-C++",
            "php": "PHP",
            "html": "HTML",
            "css": "CSS",
            "scss": "SCSS",
            "sass": "SASS",
            "less": "LESS",
            "json": "JSON",
            "yaml": "YAML",
            "yml": "YAML",
            "xml": "XML",
            "md": "Markdown",
            "sql": "SQL",
            "sh": "Shell",
            "bash": "Bash",
            "zsh": "Zsh",
            "dockerfile": "Dockerfile",
            "tf": "Terraform",
            "vue": "Vue",
            "svelte": "Svelte"
        ]
        
        return languageMap[ext]
    }
}

// MARK: - Diff Models

public struct ParsedDiff: Sendable {
    public var files: [DiffFile]
    
    public var totalAdditions: Int {
        files.reduce(0) { $0 + $1.additions }
    }
    
    public var totalDeletions: Int {
        files.reduce(0) { $0 + $1.deletions }
    }
    
    public var totalChanges: Int {
        totalAdditions + totalDeletions
    }
    
    public var fileCount: Int {
        files.count
    }
    
    public init(files: [DiffFile] = []) {
        self.files = files
    }
}

public struct DiffFile: Sendable {
    public let path: String
    public var status: FileStatus
    public var hunks: [DiffHunk]
    public var language: String?
    
    public var additions: Int {
        hunks.flatMap { $0.lines }.filter { $0.type == .addition }.count
    }
    
    public var deletions: Int {
        hunks.flatMap { $0.lines }.filter { $0.type == .deletion }.count
    }
    
    public var filename: String {
        (path as NSString).lastPathComponent
    }
    
    public var directory: String {
        (path as NSString).deletingLastPathComponent
    }
    
    public init(path: String, status: FileStatus, hunks: [DiffHunk], language: String? = nil) {
        self.path = path
        self.status = status
        self.hunks = hunks
        self.language = language
    }
}

public enum FileStatus: String, Sendable, Codable {
    case added
    case modified
    case deleted
    case renamed
    case copied
    
    public var displayName: String {
        switch self {
        case .added: return "Added"
        case .modified: return "Modified"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        }
    }
    
    public var emoji: String {
        switch self {
        case .added: return "➕"
        case .modified: return "📝"
        case .deleted: return "🗑️"
        case .renamed: return "📛"
        case .copied: return "📋"
        }
    }
}

public struct DiffHunk: Sendable {
    public var oldStart: Int
    public var oldCount: Int
    public var newStart: Int
    public var newCount: Int
    public var lines: [DiffLine]
    
    public init(oldStart: Int, oldCount: Int, newStart: Int, newCount: Int, lines: [DiffLine]) {
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.lines = lines
    }
}

public struct DiffLine: Sendable {
    public let type: DiffLineType
    public let content: String
    
    public init(type: DiffLineType, content: String) {
        self.type = type
        self.content = content
    }
}

public enum DiffLineType: String, Sendable {
    case addition
    case deletion
    case context
}
