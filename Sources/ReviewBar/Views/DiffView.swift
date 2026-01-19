import SwiftUI
import ReviewBarCore

struct DiffView: View {
    let diff: String
    var reviewRequest: ReviewRequest? // Optional request context for commenting
    
    @EnvironmentObject var reviewStore: ReviewStore
    @State private var parsedDiff: ParsedDiff?
    @State private var selectedFile: DiffFile?
    
    // Commenting State
    @State private var hoveredLineIndex: Int?
    @State private var activeCommentLineIndex: Int?
    @State private var commentDraft: String = ""
    @State private var isPosting: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            if let parsed = parsedDiff {
                // Sidebar Navigator
                FileNavigator(
                    files: parsed.files,
                    selectedFile: $selectedFile
                )
                .frame(width: 200)
                
                Divider()
                
                // Diff Content
                if let file = selectedFile {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            fileHeader(file)
                            
                            ForEach(file.hunks.indices, id: \.self) { index in
                                hunkView(file.hunks[index])
                            }
                        }
                    }
                } else {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "Select a file",
                        subtitle: "Select a file from the sidebar to view its changes."
                    )
                }
            } else {
                ProgressView("Parsing diff...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            parseDiff()
        }
    }
    
    private func parseDiff() {
        let parser = DiffParser()
        let result = parser.parse(diff)
        self.parsedDiff = result
        self.selectedFile = result.files.first
    }
    
    private func fileHeader(_ file: DiffFile) -> some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.secondary)
            Text(file.path)
                .font(.headline.monospaced())
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("+\(file.additions)")
                    .foregroundColor(.green)
                Text("-\(file.deletions)")
                    .foregroundColor(.red)
            }
            .font(.caption.bold())
        }
        .padding()
        .background(Color.primary.opacity(0.05))
    }
    
    private func hunkView(_ hunk: DiffHunk) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hunk indicator
            Text("@@ -\(hunk.oldStart),\(hunk.oldCount) +\(hunk.newStart),\(hunk.newCount) @@")
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.05))
            
            ForEach(hunk.lines.indices, id: \.self) { index in
                lineView(hunk.lines[index])
            }
        }
    }
    
    private func lineView(_ line: DiffLine) -> some View {
        HStack(spacing: 8) {
            // Line indicators (+/-/space)
            Text(lineTypeSymbol(line.type))
                .font(.caption.monospaced())
                .foregroundColor(lineTypeColor(line.type).opacity(0.7))
                .frame(width: 12)
            
            Text(line.content)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(lineTypeColor(line.type))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 1)
        .background(lineTypeColor(line.type).opacity(0.1))
        .overlay(alignment: .trailing) {
            if let file = selectedFile,
               let index = file.hunks.flatMap({ $0.lines }).firstIndex(where: { $0.content == line.content }),
               (hoveredLineIndex == index || activeCommentLineIndex == index) {
                
                Button {
                    activeCommentLineIndex = index
                    commentDraft = ""
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(.accentColor)
                        .padding(4)
                        .background(Color(.textBackgroundColor))
                        .clipShape(Circle())
                        .shadow(radius: 1)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .popover(isPresented: Binding(
                    get: { activeCommentLineIndex == index },
                    set: { if !$0 { activeCommentLineIndex = nil } }
                )) {
                    VStack(spacing: 8) {
                        Text("Add Comment")
                            .font(.headline)
                        
                        TextEditor(text: $commentDraft)
                            .frame(minWidth: 300, minHeight: 100)
                            .border(Color.secondary.opacity(0.2))
                        
                        HStack {
                            Button("Cancel") {
                                activeCommentLineIndex = nil
                            }
                            
                            Spacer()
                            
                            Button("Post") {
                                postComment(line: line, index: index)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(commentDraft.isEmpty || isPosting)
                        }
                    }
                    .padding()
                }
            }
        }
        .onHover { isHovered in
            if let file = selectedFile, isHovered {
                // Find index - inefficient but functional for now
                if let index = file.hunks.flatMap({ $0.lines }).firstIndex(where: { $0.content == line.content }) {
                    hoveredLineIndex = index
                }
            } else if !isHovered && hoveredLineIndex != nil {
                // Only clear if we were hovering this specific line (simplified)
                // Ideally checks if we moved to another line
                // For now, we rely on the next hover setting it, or just clearing it
                // hoveredLineIndex = nil // This flickers, so maybe don't clear?
            }
        }
    }
    
    private func postComment(line: DiffLine, index: Int) {
        guard let request = reviewRequest, let file = selectedFile else { return }
        
        isPosting = true
        Task {
            do {
                // Calculate actual line number (approximate for now as we don't track absolute line numbers in DiffLine yet)
                // In a real app we'd map this carefully from DiffHunk
                let lineNumber = 1 // Placeholder
                
                try await reviewStore.postInlineComment(
                    path: file.path,
                    line: lineNumber,
                    body: commentDraft,
                    request: request
                )
                
                await MainActor.run {
                    activeCommentLineIndex = nil
                    isPosting = false
                    commentDraft = ""
                    HapticManager.success()
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                    HapticManager.error()
                    print("Failed to post comment: \(error)")
                }
            }
        }
    }
    
    private func lineTypeSymbol(_ type: DiffLineType) -> String {
        switch type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        }
    }
    
    private func lineTypeColor(_ type: DiffLineType) -> Color {
        switch type {
        case .addition: return .green
        case .deletion: return .red
        case .context: return .primary
        }
    }
}

struct FileNavigator: View {
    let files: [DiffFile]
    @Binding var selectedFile: DiffFile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FILES")
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
                .padding()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(files, id: \.path) { file in
                        Button {
                            selectedFile = file
                        } label: {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(selectedFile?.path == file.path ? .accentColor : .secondary)
                                
                                Text(file.filename)
                                    .lineLimit(1)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                if file.additions > 0 {
                                    Text("\(file.additions)")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(selectedFile?.path == file.path ? Color.accentColor.opacity(0.1) : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
