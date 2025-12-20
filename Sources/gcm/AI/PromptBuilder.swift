import Foundation

struct PromptBuilder {
    let config: GCMConfiguration

    func buildPrompt(for context: GitContext) -> String {
        var prompt = ""

        // Branch context for type inference
        if let inferredType = context.inferredType {
            prompt += "Branch suggests type: \(inferredType)\n"
        }

        // Files summary
        let files = context.stagedFiles.map { $0.path.split(separator: "/").last ?? Substring($0.path) }
        prompt += "Changed: \(files.joined(separator: ", "))\n\n"

        // Diff (truncated)
        prompt += truncateDiff(context.stagedDiff)

        return prompt
    }

    func buildSystemPrompt() -> String {
        switch config.commitStyle {
        case .conventional:
            return """
            Write a git commit message in conventional commits format.

            Format: type(scope): short description

            Types:
            - feat: new feature
            - fix: bug fix
            - refactor: code change that neither fixes a bug nor adds a feature
            - docs: documentation only
            - style: formatting, missing semicolons, etc
            - test: adding tests
            - chore: maintenance

            Good examples:
            - feat(auth): add Google OAuth login
            - fix(parser): handle empty input gracefully
            - refactor(api): extract validation logic
            - docs: update installation guide

            Bad examples (DO NOT do this):
            - feat: add feature (too vague)
            - fix bug (missing type format)
            - Updated the code (not imperative, no type)

            Rules:
            - Scope is optional but helpful
            - Use imperative mood ("add" not "added")
            - Lowercase, no period at end
            - Be specific about WHAT changed
            - Max \(config.maxLength) characters
            - Output ONLY the commit message
            """

        case .gitmoji:
            return """
            Write a git commit message with an emoji prefix.

            Good examples:
            - ✨ add dark mode toggle
            - 🐛 fix login timeout on slow networks
            - ♻️ extract helper functions from main module
            - 📝 document API rate limits

            Common emojis:
            ✨ feature, 🐛 bugfix, ♻️ refactor, 📝 docs, 🎨 style, ✅ tests, 🔧 config

            Rules:
            - Start with ONE emoji
            - Be specific about the change
            - Max \(config.maxLength) characters
            - Output ONLY the commit message
            """

        case .simple:
            return """
            Write a simple git commit message.

            Good examples:
            - Add user profile page
            - Fix memory leak in image cache
            - Refactor database connection pooling
            - Update README with Docker instructions

            Rules:
            - Start with capital verb (Add, Fix, Update, Refactor, Remove)
            - Be specific about WHAT changed
            - Max \(config.maxLength) characters
            - Output ONLY the commit message
            """
        }
    }

    private func truncateDiff(_ diff: String, maxLength: Int = 4000) -> String {
        if diff.count <= maxLength { return diff }
        return String(diff.prefix(maxLength)) + "\n..."
    }
}
