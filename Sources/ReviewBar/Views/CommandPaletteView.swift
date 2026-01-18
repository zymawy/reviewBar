import SwiftUI
import ReviewBarCore

struct CommandPaletteView: View {
    @EnvironmentObject var reviewStore: ReviewStore
    @EnvironmentObject var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Input
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search reviews, settings, or actions...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .font(.title3)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color.primary.opacity(0.05))
            
            Divider()
            
            // Results
            List {
                Section("Actions") {
                    CommandRow(icon: "arrow.clockwise", title: "Refresh Reviews", shortcut: "⌘R") {
                        Task { await reviewStore.refresh() }
                        dismiss()
                    }
                    
                    CommandRow(icon: "macwindow", title: "Open Dashboard", shortcut: "⌘D") {
                        NSApp.sendAction(#selector(AppDelegate.showDashboard), to: nil, from: nil)
                        dismiss()
                    }
                    
                    CommandRow(icon: "gearshape", title: "Open Settings", shortcut: "⌘,") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        dismiss()
                    }
                }
                
                if !reviewStore.pendingReviews.isEmpty {
                    Section("Pending Reviews") {
                        ForEach(reviewStore.pendingReviews.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }) { request in
                            CommandRow(icon: "doc.text", title: request.title, subtitle: request.repository.fullName) {
                                // Action to show specific review
                                dismiss()
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: 500, height: 400)
        .onAppear {
            isFocused = true
        }
    }
}

struct CommandRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var shortcut: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
