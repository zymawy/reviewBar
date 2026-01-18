import XCTest
@testable import ReviewBarCore
import Yams

final class MCPBridgeTests: XCTestCase {
    
    var tempDir: URL!
    
    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }
    
    func testSkillLoadingAndExecution() async throws {
        // 1. Create a dummy skill
        let skillContent = """
name: test-skill
version: 1.0.0
description: A test skill
triggers:
  - file_extension: [".swift"]
rules:
  - id: no-todo
    severity: warning
    pattern: "TODO:"
    message: "No TODOs allowed"
"""
        let skillURL = tempDir.appendingPathComponent("test.yaml")
        try skillContent.write(to: skillURL, atomically: true, encoding: .utf8)
        
        // 2. Load skills
        let loader = SkillLoader()
        let skills = try await loader.loadSkills(in: tempDir)
        XCTAssertEqual(skills.count, 1)
        XCTAssertEqual(skills.first?.content.name, "test-skill")
        
        // 3. Create Bridge (moved below)
        
        // 4. Create Dummy Diff (with TODO)
        let diffText = """
diff --git a/test.swift b/test.swift
index 123..456 100644
--- a/test.swift
+++ b/test.swift
@@ -1,1 +1,2 @@
-func old() {}
+func new() {
+    // TODO: implement this
+}
"""
        let parser = DiffParser()
        let parsedDiff = parser.parse(diffText)
        
        // 5. Execute
        let bridge = MCPBridge(loader: loader, skillsDirectory: tempDir)
        let results = await bridge.executeSkills(diff: parsedDiff, skillIDs: ["test-skill"])
        
        // 6. Verify Results
        XCTAssertEqual(results.count, 1)
        let skillResult = results[0]
        XCTAssertFalse(skillResult.passed)
        XCTAssertEqual(skillResult.findings.count, 1)
        
        if let finding = skillResult.findings.first {
            XCTAssertEqual(finding.ruleID, "no-todo")
            XCTAssertEqual(finding.line, 2) // Line 2 in new file (lines: 1:func, 2:// TODO, 3:})
        }
    }
}
