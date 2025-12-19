import Foundation

/// Handles opening content in the user's preferred editor
struct EditorLauncher {
    private let executor: ShellExecutor

    init(executor: ShellExecutor = ShellExecutor()) {
        self.executor = executor
    }

    /// Get the user's preferred editor
    var preferredEditor: String {
        ProcessInfo.processInfo.environment["EDITOR"]
            ?? ProcessInfo.processInfo.environment["VISUAL"]
            ?? "vi"
    }

    /// Open content in editor and return the edited result
    func edit(_ content: String) throws -> String {
        let tempFile = createTempFile()
        defer { cleanup(tempFile) }

        try content.write(to: tempFile, atomically: true, encoding: .utf8)
        try executor.runInteractive(preferredEditor, arguments: [tempFile.path])

        let editedContent = try String(contentsOf: tempFile, encoding: .utf8)
        return editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createTempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("gcm-commit-\(UUID().uuidString).txt")
    }

    private func cleanup(_ file: URL) {
        try? FileManager.default.removeItem(at: file)
    }
}
