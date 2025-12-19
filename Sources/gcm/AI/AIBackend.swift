import Foundation

/// Protocol defining the AI backend interface for commit message generation
protocol AIBackend {
    /// Human-readable name for this backend
    var name: String { get }

    /// Check if this backend is available on the current system
    var isAvailable: Bool { get async }

    /// Generate a commit message from the given git context
    /// - Parameters:
    ///   - context: The git repository context
    ///   - config: User configuration
    /// - Returns: Generated commit message
    func generateCommitMessage(
        context: GitContext,
        config: GCMConfiguration
    ) async throws -> String
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
