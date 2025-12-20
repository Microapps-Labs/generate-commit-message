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
        if initConfig {
            try handleInitConfig()
            return
        }

        let configManager = ConfigManager()
        let config = try configManager.loadConfiguration()
        let gitAnalyzer = GitAnalyzer()

        guard await gitAnalyzer.isGitRepository() else {
            printError("Not a git repository")
            throw ExitCode.failure
        }

        let analyzeSpinner = Spinner("Analyzing")
        analyzeSpinner.start()

        let context: GitContext
        do {
            context = try await gitAnalyzer.analyze()
            analyzeSpinner.stop()
        } catch {
            analyzeSpinner.stop()
            printError("No staged changes. Run: git add <files>")
            throw ExitCode.failure
        }

        if verbose {
            print("Branch: \(context.branchName)")
            print("Files: \(context.filesSummary)")
        }

        let backend = await AIBackendFactory.createBackend()

        guard await backend.isAvailable else {
            printError("Set GCM_API_KEY for API access")
            throw ExitCode.failure
        }

        // Debug mode: dump prompt
        if ProcessInfo.processInfo.environment["DEBUG"] != nil {
            let promptBuilder = PromptBuilder(config: config)
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *), backend is AppleAIBackend {
                print("\n=== DEBUG: FEW-SHOT PROMPT (@Generable) ===")
                print(promptBuilder.buildFewShotPrompt(for: context))
                print("\n=== END DEBUG ===\n")
            } else {
                print("\n=== DEBUG: SYSTEM PROMPT ===")
                print(promptBuilder.buildSystemPrompt())
                print("\n=== DEBUG: USER PROMPT ===")
                print(promptBuilder.buildPrompt(for: context))
                print("\n=== END DEBUG ===\n")
            }
            #else
            print("\n=== DEBUG: SYSTEM PROMPT ===")
            print(promptBuilder.buildSystemPrompt())
            print("\n=== DEBUG: USER PROMPT ===")
            print(promptBuilder.buildPrompt(for: context))
            print("\n=== END DEBUG ===\n")
            #endif
        }

        let spinner = Spinner("Generating")
        spinner.start()

        let result: CommitMessageResult
        do {
            result = try await backend.generateCommitMessageWithRefinement(
                context: context,
                config: config
            )
            spinner.stop()

            if verbose && result.wasRefined {
                print("Refined (\(result.validationIssues.count) issues fixed)")
            }
        } catch {
            spinner.stop()
            printError("Generation failed: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        let message = result.message

        if dryRun {
            print(message)
            return
        }

        if noCommit {
            let editor = EditorLauncher()
            let editedMessage = try editor.edit(message)

            if editedMessage.isEmpty {
                printError("Empty message, aborting")
                throw ExitCode.failure
            }

            print(editedMessage)
            return
        }

        do {
            try await executeCommit(message: message)
            print(message)
        } catch {
            printError("Commit failed")
            throw ExitCode.failure
        }
    }

    private func handleInitConfig() throws {
        let configManager = ConfigManager()
        let configPath = GCMConfiguration.defaultConfigPath

        if FileManager.default.fileExists(atPath: configPath.path) {
            print("Config exists: \(configPath.path)")
            return
        }

        try configManager.saveConfiguration(GCMConfiguration())
        print("Created: \(configPath.path)")
    }

    private func executeCommit(message: String) async throws {
        let executor = ShellExecutor()
        _ = try await executor.run("git", arguments: ["commit", "-m", message])
    }

    private func printError(_ msg: String) {
        FileHandle.standardError.write(Data("error: \(msg)\n".utf8))
    }
}
