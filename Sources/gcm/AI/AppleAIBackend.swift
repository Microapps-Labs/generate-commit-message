import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, iOS 26.0, *)
final class AppleAIBackend: AIBackend {

    var name: String { "Apple Intelligence" }
    var supportsStreaming: Bool { true }

    var isAvailable: Bool {
        get async {
            let model = SystemLanguageModel.default
            if case .available = model.availability {
                return true
            }
            return false
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
            throw AIBackendError.unavailable(reason: "Apple Intelligence not enabled")
        }

        let promptBuilder = PromptBuilder(config: config)
        let session = LanguageModelSession(instructions: promptBuilder.buildSystemPrompt())

        var fullContent = ""
        let stream = session.streamResponse(to: promptBuilder.buildPrompt(for: context))

        for try await partial in stream {
            let current = partial.content
            if current.count > fullContent.count {
                let delta = String(current.dropFirst(fullContent.count))
                onToken(delta)
            }
            fullContent = current
        }

        return cleanMessage(fullContent)
    }

    private func cleanMessage(_ msg: String) -> String {
        var s = msg.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove quotes
        if (s.hasPrefix("\"") && s.hasSuffix("\"")) || (s.hasPrefix("'") && s.hasSuffix("'")) {
            s = String(s.dropFirst().dropLast())
        }

        // Remove code blocks
        if s.hasPrefix("```") {
            s = s.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.hasPrefix("```") }
                .joined(separator: "\n")
        }

        // Take first line only if multiple lines
        if let firstLine = s.split(separator: "\n").first {
            s = String(firstLine)
        }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#else

final class AppleAIBackend: AIBackend {
    var name: String { "Apple Intelligence (unavailable)" }
    var supportsStreaming: Bool { false }

    var isAvailable: Bool {
        get async { false }
    }

    func generateCommitMessage(context: GitContext, config: GCMConfiguration) async throws -> String {
        throw AIBackendError.unavailable(reason: "Apple Intelligence not available on this platform")
    }
}

#endif
