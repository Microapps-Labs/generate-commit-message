import Foundation

/// Commit message style options
enum CommitStyle: String, Codable, CaseIterable {
    case conventional  // feat(scope): description
    case simple        // Plain descriptive message
    case gitmoji       // :emoji: description
}

/// User configuration for gcm
struct GCMConfiguration: Codable {
    var commitStyle: CommitStyle
    var conventionalTypes: [String]
    var scopeRequired: Bool
    var maxLength: Int
    var includeBody: Bool
    var bodyMaxLength: Int
    var customInstructions: String?

    // API configuration (used when Foundation Models unavailable)
    var apiUrl: String?
    var model: String?

    init(
        commitStyle: CommitStyle = .conventional,
        conventionalTypes: [String] = ["feat", "fix", "docs", "chore", "refactor", "test", "perf", "ci", "build", "style"],
        scopeRequired: Bool = false,
        maxLength: Int = 72,
        includeBody: Bool = true,
        bodyMaxLength: Int = 500,
        customInstructions: String? = nil,
        apiUrl: String? = nil,
        model: String? = nil
    ) {
        self.commitStyle = commitStyle
        self.conventionalTypes = conventionalTypes
        self.scopeRequired = scopeRequired
        self.maxLength = maxLength
        self.includeBody = includeBody
        self.bodyMaxLength = bodyMaxLength
        self.customInstructions = customInstructions
        self.apiUrl = apiUrl
        self.model = model
    }

    static let defaultConfigPath: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/gcm/config.json")
    }()
}
