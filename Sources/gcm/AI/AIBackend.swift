import Foundation

/// Callback for streaming token updates
typealias StreamCallback = (String) -> Void

/// Protocol defining the AI backend interface for commit message generation
protocol AIBackend {
    /// Human-readable name for this backend
    var name: String { get }

    /// Check if this backend is available on the current system
    var isAvailable: Bool { get async }

    /// Whether this backend supports streaming
    var supportsStreaming: Bool { get }

    /// Generate a commit message from the given git context
    /// - Parameters:
    ///   - context: The git repository context
    ///   - config: User configuration
    /// - Returns: Generated commit message
    func generateCommitMessage(
        context: GitContext,
        config: GCMConfiguration
    ) async throws -> String

    /// Generate a commit message with streaming output
    /// - Parameters:
    ///   - context: The git repository context
    ///   - config: User configuration
    ///   - onToken: Callback invoked for each token/chunk received
    /// - Returns: Complete generated commit message
    func generateCommitMessageStreaming(
        context: GitContext,
        config: GCMConfiguration,
        onToken: @escaping StreamCallback
    ) async throws -> String
}

// Default implementation for non-streaming backends
extension AIBackend {
    var supportsStreaming: Bool { false }

    func generateCommitMessageStreaming(
        context: GitContext,
        config: GCMConfiguration,
        onToken: @escaping StreamCallback
    ) async throws -> String {
        // Fallback: generate normally, then emit all at once
        let result = try await generateCommitMessage(context: context, config: config)
        onToken(result)
        return result
    }
}

/// Errors that can occur during AI operations
enum AIBackendError: LocalizedError {
    case unavailable(reason: String)
    case apiKeyMissing
    case networkError(underlying: Error)
    case invalidResponse(String)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return "AI backend unavailable: \(reason)"
        case .apiKeyMissing:
            return "API key not found. Set GCM_API_KEY environment variable."
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .invalidResponse(let message):
            return "Invalid response from AI: \(message)"
        case .generationFailed(let message):
            return "Failed to generate commit message: \(message)"
        }
    }
}

/// Factory to select appropriate AI backend
struct AIBackendFactory {
    static func createBackend() async -> AIBackend {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let appleBackend = AppleAIBackend()
            if await appleBackend.isAvailable {
                return appleBackend
            }
        }
        #endif
        return OpenRouterBackend()
    }
}
