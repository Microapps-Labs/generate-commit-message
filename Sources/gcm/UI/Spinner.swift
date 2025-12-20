import Foundation

/// Terminal spinner for showing progress
final class Spinner {
    private let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var currentFrame = 0
    private var isRunning = false
    private var task: Task<Void, Never>?
    private var message: String

    init(message: String) {
        self.message = message
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        currentFrame = 0

        // Hide cursor
        FileHandle.standardError.write(Data("\u{001B}[?25l".utf8))

        task = Task { @MainActor in
            while self.isRunning {
                let frame = self.frames[self.currentFrame % self.frames.count]
                let output = "\r\u{001B}[K\u{001B}[36m\(frame)\u{001B}[0m \(self.message)"
                FileHandle.standardError.write(Data(output.utf8))
                self.currentFrame += 1
                try? await Task.sleep(nanoseconds: 80_000_000) // 80ms
            }
        }
    }

    func update(_ newMessage: String) {
        message = newMessage
    }

    func stop(finalMessage: String? = nil, success: Bool = true) {
        isRunning = false
        task?.cancel()

        let symbol = success ? "\u{001B}[32m✓\u{001B}[0m" : "\u{001B}[31m✗\u{001B}[0m"
        let msg = finalMessage ?? message
        let output = "\r\u{001B}[K\(symbol) \(msg)\n"
        FileHandle.standardError.write(Data(output.utf8))

        // Show cursor
        FileHandle.standardError.write(Data("\u{001B}[?25h".utf8))
    }
}

/// Progress indicator for multi-step operations
struct Progress {
    static func step(_ message: String) {
        let output = "\u{001B}[36m→\u{001B}[0m \(message)\n"
        FileHandle.standardError.write(Data(output.utf8))
    }

    static func success(_ message: String) {
        let output = "\u{001B}[32m✓\u{001B}[0m \(message)\n"
        FileHandle.standardError.write(Data(output.utf8))
    }

    static func error(_ message: String) {
        let output = "\u{001B}[31m✗\u{001B}[0m \(message)\n"
        FileHandle.standardError.write(Data(output.utf8))
    }

    static func info(_ message: String) {
        let output = "\u{001B}[90m  \(message)\u{001B}[0m\n"
        FileHandle.standardError.write(Data(output.utf8))
    }
}

/// Streaming text output that shows tokens as they arrive
final class StreamingOutput {
    private var buffer = ""
    private var lineLength = 0
    private let maxWidth: Int

    init(maxWidth: Int = 80) {
        self.maxWidth = maxWidth
    }

    func start(prefix: String = "") {
        if !prefix.isEmpty {
            FileHandle.standardError.write(Data("\(prefix)\n".utf8))
        }
        FileHandle.standardError.write(Data("\u{001B}[33m".utf8)) // Yellow for streaming
    }

    func append(_ text: String) {
        buffer += text
        FileHandle.standardError.write(Data(text.utf8))
    }

    func finish() {
        FileHandle.standardError.write(Data("\u{001B}[0m\n".utf8)) // Reset color
    }

    var content: String { buffer }
}
