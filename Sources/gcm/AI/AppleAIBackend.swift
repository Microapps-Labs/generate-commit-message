import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// AI backend using Apple's on-device Foundation Models framework
/// Available on macOS 26+, iOS 26+
@available(macOS 26.0, iOS 26.0, *)
final class AppleAIBackend: AIBackend {

    var name: String { "Apple Foundation Models" }
    var supportsStreaming: Bool { true }

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
        try await generateCommitMessageStreaming(context: context, config: config) { _ in }
    }

    func generateCommitMessageStreaming(
        context: GitContext,
        config: GCMConfiguration,
        onToken: @escaping StreamCallback
    ) async throws -> String {
        let model = SystemLanguageModel.default

        guard case .available = model.availability else {
            throw AIBackendError.unavailable(reason: "Apple Intelligence not enabled on this device")
        }

        let promptBuilder = PromptBuilder(config: config)
        let systemPrompt = promptBuilder.buildSystemPrompt()
        let userPrompt = promptBuilder.buildPrompt(for: context)

        let session = LanguageModelSession(instructions: systemPrompt)

        var fullContent = ""

        // Use streaming response
        let stream = session.streamResponse(to: userPrompt)

        for try await partial in stream {
            // Get the current content from the snapshot
            let currentContent = partial.content

            // Calculate new tokens since last update
            if currentContent.count > fullContent.count {
                let newContent = String(currentContent.dropFirst(fullContent.count))
                if !newContent.isEmpty {
                    onToken(newContent)
                }
            }
            fullContent = currentContent
        }

        return cleanCommitMessage(fullContent)
    }

    private func cleanCommitMessage(_ message: String) -> String {
        var cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)

        if (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) ||
           (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) {
            cleaned = String(cleaned.dropFirst().dropLast())
        }

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
    var supportsStreaming: Bool { false }

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
