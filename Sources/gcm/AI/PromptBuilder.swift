import Foundation

struct PromptBuilder {
    let config: GCMConfiguration

    func buildPrompt(for context: GitContext) -> String {
        var sections: [String] = []

        sections.append(buildOverview(context))
        sections.append(buildRecentCommits(context))
        sections.append(buildFilesSummary(context))
        sections.append(buildDiffs(context))

        return sections.joined(separator: "\n")
    }

    func buildSystemPrompt() -> String {
        switch config.commitStyle {
        case .conventional:
            return """
            Generate a conventional commit message.

            Format: type(scope): description

            Types: \(config.conventionalTypes.prefix(7).joined(separator: ", "))

            Rules:
            - Study RECENT COMMITS to match this repository's style
            - Analyze CHANGESET to understand scale
            - Use CATEGORIES for scope inference
            - Be specific about what changed
            - Imperative mood, lowercase, no period
            - Max \(config.maxLength) chars
            - Output ONLY the commit message

            Good examples:
            - feat(auth): add OAuth2 token refresh
            - fix(api): handle timeout in user service
            - refactor(db): extract connection pooling
            - docs(api): document rate limiting
            """

        case .gitmoji:
            return """
            Generate a gitmoji commit message.

            Good examples:
            - ✨ add dark mode toggle
            - 🐛 fix login timeout on slow networks
            - ♻️ extract helper functions
            - 📝 document API rate limits

            Emojis: ✨ feat, 🐛 fix, ♻️ refactor, 📝 docs, 🎨 style, ✅ test

            Rules:
            - Study RECENT COMMITS for style
            - Start with ONE emoji
            - Be specific
            - Max \(config.maxLength) chars
            - Output ONLY the commit message
            """

        case .simple:
            return """
            Generate a simple commit message.

            Good examples:
            - Add user profile page
            - Fix memory leak in cache
            - Refactor database connection
            - Update installation docs

            Rules:
            - Study RECENT COMMITS for style
            - Start with capital verb
            - Be specific
            - Max \(config.maxLength) chars
            - Output ONLY the commit message
            """
        }
    }

    private func buildOverview(_ context: GitContext) -> String {
        var overview = "CHANGESET:\n"
        overview += "Files: \(context.metrics.totalFiles) (\(context.filesSummary))\n"
        overview += "Lines: +\(context.metrics.totalAdditions) -\(context.metrics.totalDeletions)\n"
        overview += "Branch: \(context.branchName)"

        if let type = context.inferredType {
            overview += " [suggests: \(type)"
            if let scope = context.inferredScope {
                overview += "(\(scope))"
            }
            overview += "]"
        }

        if context.metrics.hasRenames {
            overview += " (includes renames)"
        }

        return overview
    }

    private func buildRecentCommits(_ context: GitContext) -> String {
        guard !context.recentCommits.isEmpty else { return "" }

        let maxCommits = context.metrics.isLarge ? 5 : 8
        let commits = Array(context.recentCommits.prefix(maxCommits))

        var section = "\n\nRECENT COMMITS (match this style):\n"
        for commit in commits {
            section += "  \(commit)\n"
        }

        return section
    }

    private func buildFilesSummary(_ context: GitContext) -> String {
        let cat = context.categorizedFiles
        var summary = "\n\nCATEGORIES:\n"

        if !cat.code.isEmpty {
            summary += "  Code: \(cat.code.count) files "
            let stats = cat.code.reduce((0, 0)) { ($0.0 + $1.additions, $0.1 + $1.deletions) }
            summary += "(+\(stats.0) -\(stats.1))\n"
        }

        if !cat.tests.isEmpty {
            summary += "  Tests: \(cat.tests.count) files "
            let stats = cat.tests.reduce((0, 0)) { ($0.0 + $1.additions, $0.1 + $1.deletions) }
            summary += "(+\(stats.0) -\(stats.1))\n"
        }

        if !cat.docs.isEmpty {
            summary += "  Docs: \(cat.docs.count) files "
            let stats = cat.docs.reduce((0, 0)) { ($0.0 + $1.additions, $0.1 + $1.deletions) }
            summary += "(+\(stats.0) -\(stats.1))\n"
        }

        if !cat.config.isEmpty {
            summary += "  Config: \(cat.config.count) files "
            let stats = cat.config.reduce((0, 0)) { ($0.0 + $1.additions, $0.1 + $1.deletions) }
            summary += "(+\(stats.0) -\(stats.1))\n"
        }

        return summary
    }

    private func buildDiffs(_ context: GitContext) -> String {
        let sampled = DiffSampler().sample(context: context)

        var result = "\n\nFILES:\n"

        // List files with stats
        for file in sampled.fullDiffFiles {
            let statusStr = file.oldPath != nil ? "R \(file.oldPath!) => \(file.path)" : "\(file.status.rawValue) \(file.path)"
            result += "  \(statusStr) (+\(file.additions) -\(file.deletions))\n"
        }

        if !sampled.statsOnlyFiles.isEmpty {
            result += "\nOther files (stats only):\n"
            let limited = Array(sampled.statsOnlyFiles.prefix(15))
            for file in limited {
                result += "  \(file.status.rawValue) \(file.path) (+\(file.additions) -\(file.deletions))\n"
            }
            if sampled.statsOnlyFiles.count > 15 {
                result += "  ... and \(sampled.statsOnlyFiles.count - 15) more files\n"
            }
        }

        // Include diff
        result += "\n\nDIFF:\n"
        result += truncateDiff(context.stagedDiff, maxChars: context.metrics.isLarge ? 6000 : 10000)

        return result
    }

    private func truncateDiff(_ diff: String, maxChars: Int) -> String {
        if diff.count <= maxChars {
            return diff
        }

        // Try to truncate at line boundaries
        let truncated = String(diff.prefix(maxChars))
        if let lastNewline = truncated.lastIndex(of: "\n") {
            let cleanTruncated = String(truncated[..<lastNewline])
            return cleanTruncated + "\n\n... (diff truncated, \(diff.count - cleanTruncated.count) chars omitted)"
        }

        return truncated + "\n..."
    }
}
