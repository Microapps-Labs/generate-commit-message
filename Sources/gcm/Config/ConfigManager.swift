import Foundation

/// Manages loading and saving configuration
struct ConfigManager {
    private let configPath: URL

    init(configPath: URL = GCMConfiguration.defaultConfigPath) {
        self.configPath = configPath
    }

    /// Load configuration from file, or return defaults if file doesn't exist
    func loadConfiguration() throws -> GCMConfiguration {
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return GCMConfiguration()
        }

        let data = try Data(contentsOf: configPath)
        let decoder = JSONDecoder()
        return try decoder.decode(GCMConfiguration.self, from: data)
    }

    /// Save configuration to file
    func saveConfiguration(_ config: GCMConfiguration) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        // Ensure directory exists
        let directory = configPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        try data.write(to: configPath)
    }

    /// Initialize default configuration file if it doesn't exist
    func initializeDefaultConfig() throws {
        guard !FileManager.default.fileExists(atPath: configPath.path) else {
            return
        }
        try saveConfiguration(GCMConfiguration())
    }
}
