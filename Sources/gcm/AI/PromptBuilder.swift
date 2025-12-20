import Foundation

/// Builds AI prompts from git context and configuration
struct PromptBuilder {
    let config: GCMConfiguration

    func buildPrompt(for context: GitContext) -> String {
        var prompt = """
        Generate a git commit message for the following changes.

        """

        // Add style instructions
        prompt += buildStyleInstructions()

        // Add branch context
        prompt += """


        ## Branch Context
        Current branch: \(context.branchName)
        """

        if let inferredType = context.inferredType {
            prompt += "\nInferred commit type from branch: \(inferredType)"
        }

        if let inferredScope = context.inferredScope {
            prompt += "\nInferred scope from branch: \(inferredScope)"
        }

        // Add recent commits for style reference
        if !context.recentCommits.isEmpty {
            prompt += """


            ## Recent Commits (for style reference)
            \(context.recentCommits.prefix(5).joined(separator: "\n"))
            """
        }

        // Add staged files summary
        prompt += """


        ## Staged Files (\(context.filesSummary))
        \(formatStagedFiles(context.stagedFiles))
        """

        // Add the diff
        prompt += """


        ## Staged Changes (git diff --staged)
        ```diff
        \(truncateDiff(context.stagedDiff))
        ```
        """

        // Add custom instructions if present
        if let customInstructions = config.customInstructions, !customInstructions.isEmpty {
            prompt += """


            ## Additional Instructions
            \(customInstructions)
            """
        }

        prompt += """


        Now generate the commit message. Output ONLY the commit message, nothing else (no markdown, no explanation, no quotes around it).
        """

        return prompt
    }

    /// Build the system prompt for the AI
    func buildSystemPrompt() -> String {
        """
        You are a git commit message generator.

        STRICT RULES:
        - Output ONLY the commit message, nothing else
        - Single line only, max \(config.maxLength) characters
        - No markdown, no quotes, no code blocks, no backticks
        - No explanations, no commentary, no diff output
        - Be concise: prefer short messages like "fix: resolve login bug"
        """
    }

    private func buildStyleInstructions() -> String {
        var instructions = "## Style Requirements\n"

        switch config.commitStyle {
        case .conventional:
            instructions += """
            Use Conventional Commits format: <type>(<scope>): <description>

            Valid types: \(config.conventionalTypes.joined(separator: ", "))
            Scope is \(config.scopeRequired ? "required" : "optional").
            Subject line max length: \(config.maxLength) characters.
            Use lowercase for the description. Do not end with a period.
            """

        case .simple:
            instructions += """
            Use simple descriptive format (no prefixes).
            Start with a verb in imperative mood (e.g., "Add", "Fix", "Update").
            Max length: \(config.maxLength) characters.
            """

        case .gitmoji:
            instructions += """
            Use gitmoji format: <emoji> <description>
            Start with an appropriate emoji for the change type.
            Max length: \(config.maxLength) characters.
            Common emojis:
            - :sparkles: ✨ New feature
            - :bug: 🐛 Bug fix
            - :memo: 📝 Documentation
            - :recycle: ♻️ Refactor
            - :white_check_mark: ✅ Tests
            - :zap: ⚡ Performance
            - :art: 🎨 Style/format
            - :fire: 🔥 Remove code/files
            - :construction: 🚧 Work in progress
            """
        }

        if config.includeBody {
            instructions += """


            If the changes warrant explanation, include a body after a blank line.
            The body should explain the "why" behind the changes.
            Body max length: \(config.bodyMaxLength) characters.
            """
        } else {
            instructions += "\n\nDo NOT include a body, only the subject line."
        }

        return instructions
    }

    private func formatStagedFiles(_ files: [StagedFile]) -> String {
        if files.isEmpty {
            return "(no staged files detected)"
        }
        return files.map { "\($0.status.rawValue) \($0.path)" }.joined(separator: "\n")
    }

    private func truncateDiff(_ diff: String, maxLength: Int = 8000) -> String {
        if diff.count <= maxLength {
            return diff
        }
        let truncated = String(diff.prefix(maxLength))
        return truncated + "\n\n[... diff truncated for length ...]"
    }
}
