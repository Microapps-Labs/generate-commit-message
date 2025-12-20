import Foundation

/// Sampled diff result
struct SampledDiff {
    let fullDiffFiles: [FileStats]
    let statsOnlyFiles: [FileStats]
}

/// Intelligent diff sampling for large changesets
struct DiffSampler {
    static let MAX_FULL_DIFF_FILES = 6

    func sample(context: GitContext) -> SampledDiff {
        // Small changeset: include everything
        if !context.metrics.isLarge {
            return SampledDiff(
                fullDiffFiles: context.fileStats,
                statsOnlyFiles: []
            )
        }

        // Large changeset: smart sampling
        var fullDiffFiles: [FileStats] = []
        var statsOnlyFiles: [FileStats] = []

        // Priority 1: Core code files (top 3 by change volume)
        let sortedCode = context.categorizedFiles.code.sorted { $0.totalChanges > $1.totalChanges }
        let coreFilesToInclude = min(3, sortedCode.count)
        fullDiffFiles.append(contentsOf: sortedCode.prefix(coreFilesToInclude))
        statsOnlyFiles.append(contentsOf: sortedCode.dropFirst(coreFilesToInclude))

        // Priority 2: Tests (top 2, prefer new test files)
        let sortedTests = context.categorizedFiles.tests.sorted { file1, file2 in
            if file1.status == .added && file2.status != .added { return true }
            if file2.status == .added && file1.status != .added { return false }
            return file1.totalChanges > file2.totalChanges
        }
        let testsToInclude = min(2, min(sortedTests.count, Self.MAX_FULL_DIFF_FILES - fullDiffFiles.count))
        fullDiffFiles.append(contentsOf: sortedTests.prefix(testsToInclude))
        statsOnlyFiles.append(contentsOf: sortedTests.dropFirst(testsToInclude))

        // Priority 3: Docs and config get stats-only
        statsOnlyFiles.append(contentsOf: context.categorizedFiles.docs)
        statsOnlyFiles.append(contentsOf: context.categorizedFiles.config)
        statsOnlyFiles.append(contentsOf: context.categorizedFiles.other)

        return SampledDiff(
            fullDiffFiles: fullDiffFiles,
            statsOnlyFiles: statsOnlyFiles
        )
    }
}
