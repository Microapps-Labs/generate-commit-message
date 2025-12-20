import Foundation

/// Minimal terminal spinner with streaming text support
final class Spinner: @unchecked Sendable {
    private let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var currentFrame = 0
    private var isRunning = false
    private var task: Task<Void, Never>?
    private let message: String
    private let lock = NSLock()
    private var _streamedText: String = ""

    private var streamedText: String {
        get { lock.withLock { _streamedText } }
        set { lock.withLock { _streamedText = newValue } }
    }

    init(_ message: String) {
        self.message = message
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        currentFrame = 0
        streamedText = ""

        FileHandle.standardError.write(Data("\u{001B}[?25l".utf8))

        task = Task.detached { [self] in
            while self.isRunning {
                let frame = self.frames[self.currentFrame % self.frames.count]
                let text = self.streamedText
                let display = text.isEmpty ? self.message : text
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
        FileHandle.standardError.write(Data("\r\u{001B}[K\u{001B}[?25h".utf8))
    }
}
