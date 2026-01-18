import SwiftUI
import ReviewBarCore

struct AIChatView: View {
    let reviewResult: ReviewResult
    @EnvironmentObject var settingsStore: SettingsStore
    
    @State private var messages: [ChatMessage] = []
    @State private var inputMessage: String = ""
    @State private var isSending: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat History
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                        // Initial Context Message
                        ChatMessageRow(message: ChatMessage(
                            role: .assistant,
                            content: "I've analyzed this pull request. You can ask me follow-up questions about the issues I found or for more specific suggestions."
                        ))
                        
                        ForEach(messages) { message in
                            ChatMessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let lastId = messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input Area
            HStack(spacing: DesignSystem.Spacing.small) {
                TextField("Ask a follow-up question...", text: $inputMessage)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isSending)
                
                Button(action: sendMessage) {
                    if isSending {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
    
    private func sendMessage() {
        let content = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        let userMessage = ChatMessage(role: .user, content: content)
        messages.append(userMessage)
        inputMessage = ""
        isSending = true
        
        Task {
            // Implementation of AI follow-up logic
            // In a real app, this would call the LLMProvider with the previous context
            do {
                // Simulated response for now (to be integrated with LLM service)
                try await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                let response = ChatMessage(role: .assistant, content: "I'm looking into that. Based on the code in \(reviewResult.pullRequest.author)'s PR, this would involve...")
                messages.append(response)
            } catch {
                messages.append(ChatMessage(role: .assistant, content: "Sorry, I encountered an error processing your request."))
            }
            isSending = false
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let content: String
    
    enum ChatRole {
        case user, assistant
    }
}

struct ChatMessageRow: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "ReviewBar AI")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .padding(10)
                    .background(message.role == .user ? Color.accentColor : Color.primary.opacity(0.1))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(DesignSystem.Radius.medium)
            }
            
            if message.role == .assistant { Spacer() }
        }
    }
}
