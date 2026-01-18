import Testing
@testable import ReviewBarCore

@Suite("DiffParser Tests")
struct DiffParserTests {
    
    @Test("Parse simple diff")
    func parseSimpleDiff() {
        let diff = """
        diff --git a/test.swift b/test.swift
        index 1234567..abcdefg 100644
        --- a/test.swift
        +++ b/test.swift
        @@ -1,3 +1,4 @@
         import Foundation
         
        +// New comment
         let x = 1
        """
        
        let parser = DiffParser()
        let result = parser.parse(diff)
        
        #expect(result.files.count == 1)
        #expect(result.files[0].path == "test.swift")
        #expect(result.files[0].status == .modified)
        #expect(result.totalAdditions == 1)
        #expect(result.totalDeletions == 0)
    }
    
    @Test("Parse multiple files")
    func parseMultipleFiles() {
        let diff = """
        diff --git a/file1.swift b/file1.swift
        --- a/file1.swift
        +++ b/file1.swift
        @@ -1 +1 @@
        -old line
        +new line
        diff --git a/file2.swift b/file2.swift
        new file mode 100644
        --- /dev/null
        +++ b/file2.swift
        @@ -0,0 +1 @@
        +new file content
        """
        
        let parser = DiffParser()
        let result = parser.parse(diff)
        
        #expect(result.files.count == 2)
        #expect(result.files[0].status == .modified)
        #expect(result.files[1].status == .added)
    }
    
    @Test("Detect language from extension")
    func detectLanguage() {
        let diff = """
        diff --git a/app.tsx b/app.tsx
        --- a/app.tsx
        +++ b/app.tsx
        @@ -1 +1 @@
        -old
        +new
        """
        
        let parser = DiffParser()
        let result = parser.parse(diff)
        
        #expect(result.files[0].language == "TypeScript")
    }
}

@Suite("Model Tests")
struct ModelTests {
    
    @Test("ReviewResult serialization")
    func reviewResultSerialization() throws {
        let result = ReviewResult(
            pullRequest: PullRequestSummary(
                id: "123",
                number: 42,
                title: "Test PR",
                repository: "owner/repo",
                author: "testuser",
                additions: 10,
                deletions: 5,
                changedFiles: 2,
                url: URL(string: "https://github.com")!
            ),
            duration: 1.5,
            summary: "Test summary",
            recommendation: .approve,
            confidence: 0.85,
            issues: [],
            suggestions: [],
            positives: []
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ReviewResult.self, from: data)
        
        #expect(decoded.pullRequest.number == 42)
        #expect(decoded.recommendation == .approve)
        #expect(decoded.confidence == 0.85)
    }
}
