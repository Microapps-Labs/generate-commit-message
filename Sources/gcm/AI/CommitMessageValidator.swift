import Foundation

struct ValidationIssue {
    enum Kind: String {
        case exceedsLength
        case invalidFormat
        case scopeMismatch
        case typeMismatch
        case tooGeneric
    }

    let kind: Kind
    let description: String
}

struct ValidationResult {
    let isValid: Bool
    let issues: [ValidationIssue]
}

struct CommitMessageValidator {
    let config: GCMConfiguration

    func validate(_ message: String, context: GitContext) -> ValidationResult {
        var issues: [ValidationIssue] = []

        // Check 1: Length
        if message.count > config.maxLength {
            issues.append(ValidationIssue(
                kind: .exceedsLength,
                description: "Message is \(message.count) chars, max is \(config.maxLength)"
            ))
        }

        // Check 2: Format (for conventional commits)
        if config.commitStyle == .conventional {
            let pattern = "^\\w+(\\([\\w-]+\\))?: .+"
            if message.range(of: pattern, options: .regularExpression) == nil {
                issues.append(ValidationIssue(
                    kind: .invalidFormat,
                    description: "Doesn't match type(scope): description format"
                ))
            }
        }

        // Check 3: Scope alignment with changed files
        if let scope = extractScope(message) {
            let primaryCat = determinePrimaryCategory(context.categorizedFiles)
            if !scopeMatchesCategory(scope, primaryCat) {
                issues.append(ValidationIssue(
                    kind: .scopeMismatch,
                    description: "Scope '\(scope)' doesn't match primary category '\(primaryCat)'"
                ))
            }
        }

        // Check 4: Specificity for small changes
        if context.metrics.totalFiles <= 2 {
            let genericWords = ["update", "change", "modify", "improve", "add"]
            for word in genericWords {
                if message.lowercased().contains(word + " ") || message.lowercased().hasSuffix(word) {
                    issues.append(ValidationIssue(
                        kind: .tooGeneric,
                        description: "Use more specific verb than '\(word)' for small changes"
                    ))
                    break
                }
            }
        }

        return ValidationResult(isValid: issues.isEmpty, issues: issues)
    }

    // MARK: - Helper Methods

    private func extractScope(_ message: String) -> String? {
        let pattern = "^\\w+\\(([\\w-]+)\\):"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: message) else {
            return nil
        }
        return String(message[range])
    }

    private func determinePrimaryCategory(_ categorized: CategorizedFiles) -> FileCategory {
        let categories: [(FileCategory, Int)] = [
            (.code, categorized.code.count),
            (.test, categorized.tests.count),
            (.doc, categorized.docs.count),
            (.config, categorized.config.count),
            (.other, categorized.other.count)
        ]

        return categories.max(by: { $0.1 < $1.1 })?.0 ?? .other
    }

    private func scopeMatchesCategory(_ scope: String, _ category: FileCategory) -> Bool {
        let scopeLower = scope.lowercased()

        switch category {
        case .code:
            // Extract component from paths
            // e.g., "ui", "auth", "api", etc. - accept if scope matches
            return true // For now, accept any scope for code
        case .test:
            return scopeLower == "test" || scopeLower == "tests"
        case .doc:
            return scopeLower == "doc" || scopeLower == "docs" || scopeLower == "readme"
        case .config:
            return scopeLower == "config" || scopeLower == "deps" || scopeLower == "build"
        case .other:
            return true
        }
    }
}
