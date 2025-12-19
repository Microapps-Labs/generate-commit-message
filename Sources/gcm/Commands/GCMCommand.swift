import ArgumentParser
import Foundation

@main
struct GCMCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gcm",
        abstract: "AI-powered git commit message generator",
        discussion: """
        Generates commit messages using AI based on your staged changes.

        On macOS 26+, uses Apple's on-device Foundation Models (free, private).
        On Linux or older macOS, uses OpenRouter/OpenAI API (requires GCM_API_KEY).

        Configuration file: ~/.config/gcm/config.json
        """,
        version: "1.0.0"
    )

    @Flag(name: [.customShort("n"), .long], help: "Generate message but don't commit. Opens in $EDITOR for editing.")
    var noCommit = false

    @Flag(name: .long, help: "Print the generated message without committing or editing.")
    var dryRun = false

    @Flag(name: .shortAndLong, help: "Enable verbose output.")
    var verbose = false

    @Flag(name: .long, help: "Initialize default config file at ~/.config/gcm/config.json")
    var initConfig = false

    func run() async throws {
        // Handle --init-config flag
        if initConfig {
            try handleInitConfig()
            return
        }

        let configManager = ConfigManager()
        let config = try configManager.loadConfiguration()

        let gitAnalyzer = GitAnalyzer()

        // Verify we're in a git repository
        guard await gitAnalyzer.isGitRepository() else {
            throw GitAnalyzerError.notAGitRepository
        }

        // Analyze git context
        if verbose { printInfo("Analyzing git context...") }
        let context = try await gitAnalyzer.analyze()

        if verbose {
            printInfo("Branch: \(context.branchName)")
            printInfo("Staged files: \(context.filesSummary)")
            if let inferredType = context.inferredType {
                printInfo("Inferred type: \(inferredType)")
            }
        }

        // Get AI backend
        let backend = await AIBackendFactory.createBackend()

        if verbose {
            printInfo("Using backend: \(backend.name)")
        }

        // Check if backend is available
        guard await backend.isAvailable else {
            throw AIBackendError.apiKeyMissing
        }

        // Generate commit message
        if verbose { printInfo("Generating commit message...") }
        let message = try await backend.generateCommitMessage(context: context, config: config)

        // Handle based on flags
        if dryRun {
            print(message)
            return
        }

        if noCommit {
            let editor = EditorLauncher()
            printInfo("Opening in \(editor.preferredEditor)...")
            let editedMessage = try editor.edit(message)

            if editedMessage.isEmpty {
                printError("Commit message is empty. Aborting.")
                throw ExitCode.failure
            }

            print("\nGenerated commit message:")
            print("---")
            print(editedMessage)
            print("---")
            print("\nUse this message with: git commit -m \"<message>\"")
            return
        }

        // Default: commit with generated message
        try await executeCommit(message: message)
        printSuccess("Committed with message:")
        print(message)
    }

    private func handleInitConfig() throws {
        let configManager = ConfigManager()
        let configPath = GCMConfiguration.defaultConfigPath

        if FileManager.default.fileExists(atPath: configPath.path) {
            printInfo("Config file already exists at: \(configPath.path)")
            return
        }

        try configManager.saveConfiguration(GCMConfiguration())
        printSuccess("Created default config at: \(configPath.path)")
    }

    private func executeCommit(message: String) async throws {
        let executor = ShellExecutor()
        _ = try await executor.run("git", arguments: ["commit", "-m", message])
    }

    // MARK: - Output Helpers

    private func printInfo(_ message: String) {
        FileHandle.standardError.write(Data("ℹ \(message)\n".utf8))
    }

    private func printSuccess(_ message: String) {
        FileHandle.standardError.write(Data("✓ \(message)\n".utf8))
    }

    private func printError(_ message: String) {
        FileHandle.standardError.write(Data("✗ \(message)\n".utf8))
    }
}
