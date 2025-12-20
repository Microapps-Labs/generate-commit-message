import Foundation

struct PromptBuilder {
    let config: GCMConfiguration

    func buildPrompt(for context: GitContext) -> String {
        var prompt = "Generate a commit message for these changes:\n\n"

        // Files changed
        prompt += "Files: \(formatStagedFiles(context.stagedFiles))\n\n"

        // Diff
        prompt += "Diff:\n\(truncateDiff(context.stagedDiff))\n"

        // Custom instructions
        if let custom = config.customInstructions, !custom.isEmpty {
            prompt += "\nNote: \(custom)"
        }

        return prompt
    }

    func buildSystemPrompt() -> String {
        switch config.commitStyle {
        case .conventional:
            return """
            Generate a conventional commit message. Format: type(scope): description

            Types: \(config.conventionalTypes.prefix(7).joined(separator: ", "))

            Examples:
            - feat(auth): add login with OAuth
            - fix(api): handle null response
            - refactor(utils): simplify date parsing
            - docs(readme): update install instructions

            Rules:
            - Lowercase description, no period at end
            - Max \(config.maxLength) chars
            - Output ONLY the commit message, nothing else
            """

        case .gitmoji:
            return """
            Generate a commit message with emoji prefix.

            Examples:
            - ✨ add user profile page
            - 🐛 fix login timeout issue
            - ♻️ refactor database queries
            - 📝 update API documentation

            Rules:
            - Start with relevant emoji
            - Max \(config.maxLength) chars
            - Output ONLY the commit message, nothing else
            """

        case .simple:
            return """
            Generate a simple commit message.

            Examples:
            - Add user authentication
            - Fix memory leak in cache
            - Update dependencies
            - Refactor payment module

            Rules:
            - Start with capital verb (Add, Fix, Update, etc.)
            - Max \(config.maxLength) chars
            - Output ONLY the commit message, nothing else
            """
        }
    }

    private func formatStagedFiles(_ files: [StagedFile]) -> String {
        if files.isEmpty { return "(none)" }
        return files.map { "\($0.status.rawValue) \($0.path)" }.joined(separator: ", ")
    }

    private func truncateDiff(_ diff: String, maxLength: Int = 6000) -> String {
        if diff.count <= maxLength { return diff }
        return String(diff.prefix(maxLength)) + "\n[truncated]"
    }
}
