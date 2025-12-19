import Foundation

/// Errors that can occur during git analysis
enum GitAnalyzerError: LocalizedError {
    case noStagedChanges
    case notAGitRepository

    var errorDescription: String? {
        switch self {
        case .noStagedChanges:
            return "No staged changes found. Stage changes with 'git add' first."
        case .notAGitRepository:
            return "Not a git repository."
        }
    }
}

/// Analyzes the current git repository state
struct GitAnalyzer {
    private let executor: ShellExecutor

    init(executor: ShellExecutor = ShellExecutor()) {
        self.executor = executor
    }

    /// Analyze the current git context
    func analyze() async throws -> GitContext {
        // Run git commands concurrently for performance
        async let diffTask = executor.run("git", "diff", "--staged")
        async let logTask = safeRun("git", "log", "--oneline", "-10")
        async let branchTask = safeRun("git", "branch", "--show-current")
        async let statusTask = executor.run("git", "status", "--porcelain")

        let (diff, log, branch, status) = try await (diffTask, logTask, branchTask, statusTask)

        // Validate we have staged changes
        guard !diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GitAnalyzerError.noStagedChanges
        }

        let recentCommits = log
            .split(separator: "\n")
            .map(String.init)

        let stagedFiles = parseStagedFiles(status)

        return GitContext(
            stagedDiff: diff,
            recentCommits: recentCommits,
            branchName: branch.trimmingCharacters(in: .whitespacesAndNewlines),
            stagedFiles: stagedFiles
        )
    }

    /// Check if current directory is a git repository
    func isGitRepository() async -> Bool {
        do {
            _ = try await executor.run("git", "rev-parse", "--is-inside-work-tree")
            return true
        } catch {
            return false
        }
    }

    /// Run a command that might fail (e.g., git log on empty repo) and return empty string on failure
    private func safeRun(_ command: String, _ arguments: String...) async -> String {
        do {
            return try await executor.run(command, arguments: arguments)
        } catch {
            return ""
        }
    }

    private func parseStagedFiles(_ status: String) -> [StagedFile] {
        status.split(separator: "\n").compactMap { line in
            let lineStr = String(line)
            guard lineStr.count >= 3 else { return nil }

            // git status --porcelain format: XY filename
            // X = index status, Y = working tree status
            // We care about X (staged changes)
            let indexStatus = String(lineStr.prefix(1))
            let path = String(lineStr.dropFirst(3))

            // Only include files that are staged (have a non-space, non-? index status)
            guard indexStatus != " " && indexStatus != "?" else {
                // Check if it's a working tree change we should mention
                if lineStr.prefix(2) == "??" {
                    // Untracked file, skip
                    return nil
                }
                return nil
            }

            guard let status = StagedFile.Status(rawValue: indexStatus) else {
                return nil
            }

            return StagedFile(status: status, path: path)
        }
    }
}
