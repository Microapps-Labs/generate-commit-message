import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, iOS 26.0, *)
final class AppleAIBackend: AIBackend {

    var name: String { "Apple Intelligence" }
    var supportsStreaming: Bool { false }  // @Generable doesn't stream well

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
        let model = SystemLanguageModel.default

        guard case .available = model.availability else {
            throw AIBackendError.unavailable(reason: "Apple Intelligence not enabled")
        }

        let promptBuilder = PromptBuilder(config: config)
        let session = LanguageModelSession()

        // Use structured generation with @Generable
        let response = try await session.respond(
            to: promptBuilder.buildFewShotPrompt(for: context),
            generating: CommitMessage.self
        )

        return response.content.format()
    }

    func generateCommitMessageStreaming(
        context: GitContext,
        config: GCMConfiguration,
        onToken: @escaping StreamCallback
    ) async throws -> String {
        // @Generable doesn't support token streaming
        // Generate and emit all at once
        let result = try await generateCommitMessage(context: context, config: config)
        onToken(result)
        return result
    }

    func refineMessage(
        draft: String,
        context: GitContext,
        config: GCMConfiguration,
        issues: [ValidationIssue]
    ) async throws -> String {
        // For now, structured generation is good enough
        // Refinement may not be needed
        return draft
    }
}

extension CategorizedFiles {
    func count(for category: FileCategory) -> Int {
        switch category {
        case .code: return code.count
        case .test: return tests.count
        case .doc: return docs.count
        case .config: return config.count
        case .other: return other.count
        }
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

    func refineMessage(draft: String, context: GitContext, config: GCMConfiguration, issues: [ValidationIssue]) async throws -> String {
        return draft
    }
}

#endif
