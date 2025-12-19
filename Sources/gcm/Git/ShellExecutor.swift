import Foundation

/// Errors that can occur during shell execution
enum ShellError: LocalizedError {
    case executionFailed(Error)
    case commandFailed(code: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .executionFailed(let error):
            return "Failed to execute command: \(error.localizedDescription)"
        case .commandFailed(let code, let stderr):
            if stderr.isEmpty {
                return "Command failed with exit code \(code)"
            }
            return "Command failed with exit code \(code): \(stderr)"
        }
    }
}

/// Executes shell commands using Foundation's Process
struct ShellExecutor {

    /// Execute a command and return its stdout
    func run(_ command: String, _ arguments: String...) async throws -> String {
        try await run(command, arguments: arguments)
    }

    func run(_ command: String, arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ShellError.executionFailed(error))
                return
            }

            process.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                continuation.resume(returning: stdout)
            } else {
                continuation.resume(throwing: ShellError.commandFailed(
                    code: process.terminationStatus,
                    stderr: stderr
                ))
            }
        }
    }

    /// Execute a command and stream output (for interactive processes like editors)
    func runInteractive(_ command: String, arguments: [String] = []) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ShellError.commandFailed(code: process.terminationStatus, stderr: "")
        }
    }
}
