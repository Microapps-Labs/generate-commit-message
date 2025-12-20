import Foundation

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

struct GitAnalyzer {
    private let executor: ShellExecutor

    init(executor: ShellExecutor = ShellExecutor()) {
        self.executor = executor
    }

    func analyze() async throws -> GitContext {
        // Run 6 git commands concurrently
        async let numstatTask = executor.run("git", "diff", "--staged", "--numstat", "-M")
        async let statTask = executor.run("git", "diff", "--staged", "--stat", "-M")
        async let diffTask = executor.run("git", "diff", "--staged", "-M")
        async let logTask = safeRun("git", "log", "--oneline", "-10")
        async let branchTask = safeRun("git", "branch", "--show-current")
        async let statusTask = executor.run("git", "status", "--porcelain", "-M")

        let (numstat, stat, diff, log, branch, status) =
            try await (numstatTask, statTask, diffTask, logTask, branchTask, statusTask)

        guard !diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GitAnalyzerError.noStagedChanges
        }

        let recentCommits = log.split(separator: "\n").map(String.init)
        let stagedFiles = parseStagedFiles(status)
        let fileStats = parseNumstat(numstat, stagedFiles: stagedFiles)
        let categorizedFiles = categorizeFiles(fileStats)
        let metrics = calculateMetrics(fileStats)

        return GitContext(
            stagedDiff: diff,
            recentCommits: recentCommits,
            branchName: branch.trimmingCharacters(in: .whitespacesAndNewlines),
            stagedFiles: stagedFiles,
            fileStats: fileStats,
            statSummary: stat,
            categorizedFiles: categorizedFiles,
            metrics: metrics
        )
    }

    func isGitRepository() async -> Bool {
        do {
            _ = try await executor.run("git", "rev-parse", "--is-inside-work-tree")
            return true
        } catch {
            return false
        }
    }

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

            let indexStatus = String(lineStr.prefix(1))
            let path = String(lineStr.dropFirst(3))

            guard indexStatus != " " && indexStatus != "?" else {
                return nil
            }

            guard let status = StagedFile.Status(rawValue: indexStatus) else {
                return nil
            }

            return StagedFile(status: status, path: path)
        }
    }

    private func parseNumstat(_ numstat: String, stagedFiles: [StagedFile]) -> [FileStats] {
        let statusMap = Dictionary(uniqueKeysWithValues: stagedFiles.map { ($0.path, $0.status) })

        return numstat.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 2)
            guard parts.count == 3 else { return nil }

            let addStr = String(parts[0])
            let delStr = String(parts[1])
            var path = String(parts[2])

            let additions = Int(addStr) ?? -1
            let deletions = Int(delStr) ?? -1

            var oldPath: String? = nil

            // Detect renames: "old => new" or "{old => new}"
            if path.contains(" => ") {
                let renameParts = path.split(separator: " => ", maxSplits: 1)
                if renameParts.count == 2 {
                    oldPath = String(renameParts[0])
                        .trimmingCharacters(in: CharacterSet(charactersIn: "{}").union(.whitespaces))
                    path = String(renameParts[1])
                        .trimmingCharacters(in: CharacterSet(charactersIn: "{}").union(.whitespaces))
                }
            }

            let status = statusMap[path] ?? (oldPath != nil ? .renamed : .modified)
            let category = categorizeFile(path)

            return FileStats(
                path: path,
                additions: additions,
                deletions: deletions,
                status: status,
                oldPath: oldPath,
                category: category
            )
        }
    }

    private func categorizeFile(_ path: String) -> FileCategory {
        let lower = path.lowercased()
        let filename = lower.split(separator: "/").last.map(String.init) ?? lower

        // Tests (check first)
        if lower.contains("/test") || lower.contains("/tests/") ||
           filename.hasSuffix("test.swift") || filename.hasSuffix("tests.swift") ||
           filename.hasPrefix("test_") ||
           filename.hasSuffix(".test.js") || filename.hasSuffix(".test.ts") ||
           filename.hasSuffix(".spec.js") || filename.hasSuffix(".spec.ts") {
            return .test
        }

        // Docs
        if filename.hasSuffix(".md") || filename.hasSuffix(".txt") ||
           filename.hasSuffix(".rst") || filename.hasSuffix(".adoc") ||
           lower.contains("/docs/") {
            return .doc
        }

        // Config
        if filename.hasSuffix(".json") || filename.hasSuffix(".yaml") ||
           filename.hasSuffix(".yml") || filename.hasSuffix(".toml") ||
           filename.hasSuffix(".xml") || filename.hasSuffix(".ini") ||
           filename == "package.swift" || filename == "makefile" ||
           filename.hasSuffix(".lock") || filename == ".gitignore" {
            return .config
        }

        // Code
        if filename.hasSuffix(".swift") || filename.hasSuffix(".py") ||
           filename.hasSuffix(".js") || filename.hasSuffix(".ts") ||
           filename.hasSuffix(".jsx") || filename.hasSuffix(".tsx") ||
           filename.hasSuffix(".go") || filename.hasSuffix(".rs") ||
           filename.hasSuffix(".java") || filename.hasSuffix(".kt") ||
           filename.hasSuffix(".c") || filename.hasSuffix(".cpp") ||
           filename.hasSuffix(".h") || filename.hasSuffix(".hpp") ||
           filename.hasSuffix(".rb") || filename.hasSuffix(".php") {
            return .code
        }

        return .other
    }

    private func categorizeFiles(_ fileStats: [FileStats]) -> CategorizedFiles {
        var code: [FileStats] = []
        var tests: [FileStats] = []
        var docs: [FileStats] = []
        var config: [FileStats] = []
        var other: [FileStats] = []

        for file in fileStats {
            switch file.category {
            case .code: code.append(file)
            case .test: tests.append(file)
            case .doc: docs.append(file)
            case .config: config.append(file)
            case .other: other.append(file)
            }
        }

        return CategorizedFiles(
            code: code,
            tests: tests,
            docs: docs,
            config: config,
            other: other
        )
    }

    private func calculateMetrics(_ fileStats: [FileStats]) -> ChangesetMetrics {
        let totalFiles = fileStats.count
        let totalAdditions = fileStats.filter { !$0.isBinary }.reduce(0) { $0 + $1.additions }
        let totalDeletions = fileStats.filter { !$0.isBinary }.reduce(0) { $0 + $1.deletions }
        let hasRenames = fileStats.contains { $0.oldPath != nil }

        return ChangesetMetrics(
            totalFiles: totalFiles,
            totalAdditions: totalAdditions,
            totalDeletions: totalDeletions,
            hasRenames: hasRenames
        )
    }
}
