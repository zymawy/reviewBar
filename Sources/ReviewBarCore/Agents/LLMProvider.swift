import Foundation

/// Protocol for LLM providers (Claude, OpenAI, Gemini, Ollama)
public protocol LLMProvider: Sendable {
    /// Unique identifier
    var id: String { get }
    
    /// Display name
    var displayName: String { get }
    
    /// Available models
    var supportedModels: [String] { get }
    
    /// Complete a prompt synchronously
    func complete(prompt: String, model: String) async throws -> String
    
    /// Stream a completion
    nonisolated func streamComplete(prompt: String, model: String) -> AsyncThrowingStream<String, Error>
}

// MARK: - LLM Errors

public enum LLMError: LocalizedError {
    case invalidAPIKey
    case modelNotFound(String)
    case rateLimited(retryAfter: TimeInterval?)
    case contextTooLong(maxTokens: Int)
    case networkError(Error)
    case parseError(String)
    case serverError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your credentials."
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Please retry after \(Int(seconds)) seconds."
            }
            return "Rate limited. Please try again later."
        case .contextTooLong(let maxTokens):
            return "Input too long. Maximum context is \(maxTokens) tokens."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parseError(let message):
            return "Failed to parse response: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// MARK: - Claude Provider

public actor ClaudeProvider: LLMProvider {
    
    public nonisolated let id = "claude"
    public nonisolated let displayName = "Claude"
    public nonisolated let supportedModels = [
        "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku-20241022",
        "claude-3-opus-20240229"
    ]
    
    private let apiKey: String
    private let session: URLSession
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    
    public init(apiKey: String) {
        self.apiKey = apiKey
        self.session = URLSession.shared
    }
    
    public func complete(prompt: String, model: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(URLError(.badServerResponse))
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw LLMError.invalidAPIKey
        case 429:
            throw LLMError.rateLimited(retryAfter: nil)
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.serverError(message)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw LLMError.parseError("Failed to extract response text")
        }
        
        return text
    }
    
    public nonisolated func streamComplete(prompt: String, model: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await complete(prompt: prompt, model: model)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - OpenAI Provider

public actor OpenAIProvider: LLMProvider {
    
    public nonisolated let id = "openai"
    public nonisolated let displayName = "OpenAI"
    public nonisolated let supportedModels = [
        "gpt-4o",
        "gpt-4o-mini",
        "gpt-4-turbo",
        "o1",
        "o1-mini"
    ]
    
    private let apiKey: String
    private let session: URLSession
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    
    public init(apiKey: String) {
        self.apiKey = apiKey
        self.session = URLSession.shared
    }
    
    public func complete(prompt: String, model: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 4096
        ]
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(URLError(.badServerResponse))
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw LLMError.invalidAPIKey
        case 429:
            throw LLMError.rateLimited(retryAfter: nil)
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.serverError(message)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.parseError("Failed to extract response text")
        }
        
        return content
    }
    
    public nonisolated func streamComplete(prompt: String, model: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await complete(prompt: prompt, model: model)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Ollama Provider (Local)

public actor OllamaProvider: LLMProvider {
    
    public nonisolated let id = "ollama"
    public nonisolated let displayName = "Ollama (Local)"
    public nonisolated let supportedModels = [
        "codellama",
        "deepseek-coder",
        "llama3.1"
    ]
    
    private let baseURL: URL
    private let session: URLSession
    
    public init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.baseURL = baseURL
        self.session = URLSession.shared
    }
    
    public func complete(prompt: String, model: String) async throws -> String {
        let url = baseURL.appendingPathComponent("api/generate")
        
        let requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(URLError(.badServerResponse))
        }
        
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.serverError(message)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            throw LLMError.parseError("Failed to extract response text")
        }
        
        return responseText
    }
    
    public nonisolated func streamComplete(prompt: String, model: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await complete(prompt: prompt, model: model)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
