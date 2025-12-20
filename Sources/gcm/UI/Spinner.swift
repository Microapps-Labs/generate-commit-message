import Foundation

/// Minimal terminal spinner with streaming text support
@MainActor
final class Spinner {
    private let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var currentFrame = 0
    private var isRunning = false
    private var task: Task<Void, Never>?
    private var message: String
    private var streamedText: String = ""

    init(_ message: String) {
        self.message = message
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        currentFrame = 0
        streamedText = ""

        // Hide cursor
        FileHandle.standardError.write(Data("\u{001B}[?25l".utf8))

        task = Task {
            while self.isRunning {
                let frame = self.frames[self.currentFrame % self.frames.count]
                let display = self.streamedText.isEmpty ? self.message : self.streamedText
                FileHandle.standardError.write(Data("\r\u{001B}[K\(frame) \(display)".utf8))
                self.currentFrame += 1
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }
    }

    func stream(_ text: String) {
        streamedText += text
    }

    func stop() {
        isRunning = false
        task?.cancel()
        // Clear line and show cursor
        FileHandle.standardError.write(Data("\r\u{001B}[K\u{001B}[?25h".utf8))
    }
}
