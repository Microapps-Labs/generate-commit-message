import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// AI backend using Apple's on-device Foundation Models framework
/// Available on macOS 26+, iOS 26+
@available(macOS 26.0, iOS 26.0, *)
final class AppleAIBackend: AIBackend {

    var name: String { "Apple Foundation Models" }

    var isAvailable: Bool {
        get async {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return true
            case .unavailable:
                return false
            @unknown default:
                return false
            }
        }
    }

    func generateCommitMessage(
        context: GitContext,
        config: GCMConfiguration
    ) async throws -> String {
        let model = SystemLanguageModel.default

        guard case .available = model.availability else {
            throw AIBackendError.unavailable(reason: "Apple Intelligence not enabled on this device")
        }

        let promptBuilder = PromptBuilder(config: config)
        let systemPrompt = promptBuilder.buildSystemPrompt()
        let userPrompt = promptBuilder.buildPrompt(for: context)

        let session = LanguageModelSession(
            instructions: systemPrompt
        )

        let response = try await session.respond(to: userPrompt)
        return cleanCommitMessage(response.content)
    }

    /// Clean up the commit message (remove quotes, markdown, etc.)
    private func cleanCommitMessage(_ message: String) -> String {
        var cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove surrounding quotes if present
        if (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) ||
           (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) {
            cleaned = String(cleaned.dropFirst().dropLast())
        }

        // Remove markdown code block if present
        if cleaned.hasPrefix("```") {
            let lines = cleaned.split(separator: "\n", omittingEmptySubsequences: false)
            let filtered = lines.filter { !$0.hasPrefix("```") }
            cleaned = filtered.joined(separator: "\n")
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#else

/// Stub implementation when FoundationModels is not available (Linux, older macOS)
final class AppleAIBackend: AIBackend {
    var name: String { "Apple Foundation Models (unavailable)" }

    var isAvailable: Bool {
        get async { false }
    }

    func generateCommitMessage(
        context: GitContext,
        config: GCMConfiguration
    ) async throws -> String {
        throw AIBackendError.unavailable(reason: "Apple Foundation Models not available on this platform")
    }
}

#endif
