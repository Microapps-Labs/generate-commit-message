import Foundation

/// Represents a staged file with its status
struct StagedFile {
    enum Status: String {
        case added = "A"
        case modified = "M"
        case deleted = "D"
        case renamed = "R"
        case copied = "C"
        case untracked = "?"
    }

    let status: Status
    let path: String
}

/// Detailed statistics for a single file
struct FileStats {
    let path: String
    let additions: Int
    let deletions: Int
    let status: StagedFile.Status
    let oldPath: String?
    let category: FileCategory

    var totalChanges: Int { additions + deletions }
    var isBinary: Bool { additions == -1 && deletions == -1 }
}

/// File categorization for intelligent context allocation
enum FileCategory: String, Codable {
    case code
    case test
    case doc
    case config
    case other

    var weight: Double {
        switch self {
        case .code: return 1.0
        case .test: return 0.6
        case .doc: return 0.3
        case .config: return 0.2
        case .other: return 0.1
        }
    }
}

/// Files grouped by category
struct CategorizedFiles {
    let code: [FileStats]
    let tests: [FileStats]
    let docs: [FileStats]
    let config: [FileStats]
    let other: [FileStats]

    var totalFiles: Int {
        code.count + tests.count + docs.count + config.count + other.count
    }
}

/// Overall changeset metrics
struct ChangesetMetrics {
    let totalFiles: Int
    let totalAdditions: Int
    let totalDeletions: Int
    let hasRenames: Bool

    var totalChanges: Int { totalAdditions + totalDeletions }
    var isLarge: Bool { totalFiles > 10 || totalChanges > 500 }
}

/// Represents the current git repository context for commit message generation
struct GitContext {
    /// Staged diff content from `git diff --staged`
    let stagedDiff: String

    /// Recent commit history for style inference
    let recentCommits: [String]

    /// Current branch name
    let branchName: String

    /// Summary of staged files (from git status --porcelain)
    let stagedFiles: [StagedFile]

    /// Per-file statistics from --numstat
    let fileStats: [FileStats]

    /// Human-readable stat summary from --stat
    let statSummary: String

    /// Files categorized by type
    let categorizedFiles: CategorizedFiles

    /// Overall changeset metrics
    let metrics: ChangesetMetrics

    /// Inferred commit type based on branch name
    var inferredType: String? {
        let lowercased = branchName.lowercased()
        if lowercased.hasPrefix("feature/") || lowercased.hasPrefix("feat/") {
            return "feat"
        } else if lowercased.hasPrefix("fix/") || lowercased.hasPrefix("bugfix/") || lowercased.hasPrefix("hotfix/") {
            return "fix"
        } else if lowercased.hasPrefix("docs/") {
            return "docs"
        } else if lowercased.hasPrefix("refactor/") {
            return "refactor"
        } else if lowercased.hasPrefix("test/") {
            return "test"
        } else if lowercased.hasPrefix("chore/") {
            return "chore"
        } else if lowercased.hasPrefix("perf/") {
            return "perf"
        } else if lowercased.hasPrefix("ci/") {
            return "ci"
        } else if lowercased.hasPrefix("build/") {
            return "build"
        } else if lowercased.hasPrefix("style/") {
            return "style"
        }
        return nil
    }

    /// Inferred scope from branch name (e.g., "feature/auth" -> "auth")
    var inferredScope: String? {
        let components = branchName.split(separator: "/")
        guard components.count >= 2 else { return nil }
        return String(components[1])
    }

    /// Summary of what files are being changed
    var filesSummary: String {
        let added = stagedFiles.filter { $0.status == .added }.count
        let modified = stagedFiles.filter { $0.status == .modified }.count
        let deleted = stagedFiles.filter { $0.status == .deleted }.count

        var parts: [String] = []
        if added > 0 { parts.append("\(added) added") }
        if modified > 0 { parts.append("\(modified) modified") }
        if deleted > 0 { parts.append("\(deleted) deleted") }

        return parts.isEmpty ? "no files" : parts.joined(separator: ", ")
    }
}
