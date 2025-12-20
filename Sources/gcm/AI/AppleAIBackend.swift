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

    func refineMessage(
        draft: String,
        context: GitContext,
        config: GCMConfiguration,
        issues: [ValidationIssue]
    ) async throws -> String {
        let refinementPrompt = buildRefinementPrompt(draft: draft, context: context, config: config, issues: issues)
        let session = LanguageModelSession(instructions: refinementSystemPrompt)
        let response = try await session.respond(to: refinementPrompt)
        return cleanMessage(response.content)
    }

    private var refinementSystemPrompt: String {
        """
        You are a commit message editor. Fix specific issues while preserving core meaning.
        Output ONLY the revised commit message in conventional format: type(scope): description
        Be precise and concise.
        """
    }

    private func buildRefinementPrompt(draft: String, context: GitContext, config: GCMConfiguration, issues: [ValidationIssue]) -> String {
        var prompt = "DRAFT MESSAGE:\n\(draft)\n\nISSUES FOUND:\n"

        for issue in issues {
            prompt += "- \(issue.description)\n"
        }

        let primaryCat = determinePrimaryCategory(context.categorizedFiles)
        let topFiles = Array(context.fileStats.sorted { $0.totalChanges > $1.totalChanges }.prefix(3))

        let maxLen = config.maxLength
        prompt += """

        CONTEXT REMINDER:
        - Primary category: \(primaryCat.rawValue) (\(context.categorizedFiles.count(for: primaryCat)) files)
        - Key files: \(topFiles.map { $0.path }.joined(separator: ", "))
        - Change nature: \(inferChangeNature(context))

        TASK: Revise the commit message to fix all issues above.
        Keep under \(maxLen) characters.
        Output ONLY the revised message.
        """

        return prompt
    }

    private func determinePrimaryCategory(_ categorized: CategorizedFiles) -> FileCategory {
        let counts = [
            (FileCategory.code, categorized.code.count),
            (FileCategory.test, categorized.tests.count),
            (FileCategory.doc, categorized.docs.count),
            (FileCategory.config, categorized.config.count),
            (FileCategory.other, categorized.other.count)
        ]
        return counts.max(by: { $0.1 < $1.1 })?.0 ?? .other
    }

    private func inferChangeNature(_ context: GitContext) -> String {
        let hasNew = context.fileStats.contains { $0.status == .added }
        let hasDeleted = context.fileStats.contains { $0.status == .deleted }
        let hasRenamed = context.fileStats.contains { $0.oldPath != nil }

        if hasNew && !hasDeleted { return "new functionality" }
        if hasDeleted && !hasNew { return "removal" }
        if hasRenamed { return "refactoring/restructuring" }
        return "modification"
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
}

#endif
