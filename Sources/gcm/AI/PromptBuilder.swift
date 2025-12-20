import Foundation

struct PromptBuilder {
    let config: GCMConfiguration

    func buildFewShotPrompt(for context: GitContext) -> String {
        """
        Generate a commit message by analyzing the code changes.

        Example patterns:

        If FILES shows: A src/auth/Login.swift (+67 -0)
        And DIFF shows: new login screen functionality
        Then: type=feat, scope=auth, description=add login screen

        If FILES shows: M src/api/User.swift (+8 -12)
        And DIFF shows: null check fix
        Then: type=fix, scope=api, description=prevent null pointer crash

        If FILES shows: M README.md (+34 -12)
        And DIFF shows: documentation additions
        Then: type=docs, scope= , description=add installation instructions

        If FILES shows: M Package.swift (+2 -2)
        And DIFF shows: dependency version bumps
        Then: type=chore, scope= , description=upgrade dependencies

        Now analyze these changes:

        FILES:
        \(formatFilesList(context.fileStats))

        Key changes in diff:
        \(extractKeyDiffLines(context.stagedDiff))

        Generate the commit components.
        """
    }

    private func formatFilesList(_ stats: [FileStats]) -> String {
        stats.prefix(10).map { file in
            if let old = file.oldPath {
                return "R \(old) => \(file.path) (+\(file.additions) -\(file.deletions))"
            } else {
                return "\(file.status.rawValue) \(file.path) (+\(file.additions) -\(file.deletions))"
            }
        }.joined(separator: "\n")
    }

    // Legacy prompt (for OpenRouter backend)
    func buildPrompt(for context: GitContext) -> String {
        var prompt = "FILES:\n"

        for file in context.fileStats {
            if let oldPath = file.oldPath {
                prompt += "R \(oldPath) => \(file.path) (+\(file.additions) -\(file.deletions))\n"
            } else {
                prompt += "\(file.status.rawValue) \(file.path) (+\(file.additions) -\(file.deletions))\n"
            }
        }

        prompt += "\nDIFF:\n"
        prompt += truncateDiff(context.stagedDiff, maxChars: 8000)

        return prompt
    }

    private func extractKeyDiffLines(_ diff: String) -> String {
        // Extract key changes, skip boilerplate
        let lines = diff.split(separator: "\n")
        let keyLines = lines.compactMap { line -> String? in
            guard line.hasPrefix("+") && !line.hasPrefix("+++") else { return nil }

            let content = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)

            // Skip boilerplate
            if content.isEmpty ||
               content.starts(with: "import ") ||
               content.starts(with: "//") ||
               content.starts(with: "#if") ||
               content.starts(with: "#end") ||
               content.starts(with: "#else") ||
               content.starts(with: "@available") ||
               content.starts(with: "package ") ||
               content == "{" || content == "}" {
                return nil
            }

            return "+\(content)"
        }

        let excerpt = keyLines.prefix(5).joined(separator: " ")
        let truncated = String(excerpt.prefix(200))
        return truncated.isEmpty ? "(new file)" : truncated
    }

    func buildSystemPrompt() -> String {
        switch config.commitStyle {
        case .conventional:
            return """
            Write a git commit message.

            FORMAT: type(scope): description

            TYPES:
            feat - new feature
            fix - bug fix
            docs - documentation
            chore - maintenance (deps, config, tooling)
            refactor - code restructure, no behavior change
            test - add or modify tests
            perf - performance improvement

            SCOPE: Optional. Use component/file name if focused (1-3 related files), omit if broad changes.

            PROCESS:
            1. Read the DIFF - what was actually added, removed, or modified?
            2. Determine type based on the nature of changes
            3. Add scope if changes are in a specific component
            4. Write description starting with a verb

            EXAMPLES:
            feat(auth): add password reset endpoint
            fix(api): prevent null pointer in user service
            docs: add installation instructions
            chore: update dependencies to latest versions
            refactor(parser): extract validation into separate module
            test(auth): add integration tests for OAuth flow

            RULES:
            - Imperative mood ("add" not "added")
            - Lowercase description
            - No period at end
            - Max \(config.maxLength) characters
            - Be specific about what changed

            Output ONLY the commit message.
            """

        case .gitmoji:
            return """
            Write a git commit message with emoji.

            FORMAT: <emoji> description

            EMOJIS:
            ✨ feat - new feature
            🐛 fix - bug fix
            📝 docs - documentation
            🔧 chore - maintenance
            ♻️ refactor - code restructure
            ✅ test - tests
            ⚡ perf - performance

            PROCESS:
            1. Read the DIFF - what changed?
            2. Pick appropriate emoji
            3. Write description with verb

            EXAMPLES:
            ✨ add dark mode support
            🐛 fix crash on empty input
            📝 document API endpoints
            🔧 update build configuration
            ♻️ simplify error handling logic

            Max \(config.maxLength) chars. Be specific.
            Output ONLY the commit message.
            """

        case .simple:
            return """
            Write a simple git commit message.

            PROCESS:
            1. Read the DIFF - what changed?
            2. Start with a capital verb
            3. Be specific about the change

            EXAMPLES:
            Add user authentication system
            Fix memory leak in image cache
            Update installation documentation
            Refactor database connection pooling
            Remove deprecated API endpoints

            Max \(config.maxLength) chars. Be specific.
            Output ONLY the commit message.
            """
        }
    }

    private func truncateDiff(_ diff: String, maxChars: Int) -> String {
        if diff.count <= maxChars {
            return diff
        }

        let truncated = String(diff.prefix(maxChars))
        if let lastNewline = truncated.lastIndex(of: "\n") {
            let cleanTruncated = String(truncated[..<lastNewline])
            return cleanTruncated + "\n\n... (diff truncated, \(diff.count - cleanTruncated.count) chars omitted)"
        }

        return truncated + "\n..."
    }
}
