import Foundation

/// AI backend using OpenRouter or OpenAI-compatible APIs
final class OpenRouterBackend: AIBackend {

    private let defaultApiUrl = "https://openrouter.ai/api/v1/chat/completions"
    private let defaultModel = "anthropic/claude-3.5-sonnet"

    var name: String { "OpenRouter API" }
    var supportsStreaming: Bool { true }

    var isAvailable: Bool {
        get async {
            return getApiKey() != nil
        }
    }

    func generateCommitMessage(
        context: GitContext,
        config: GCMConfiguration
    ) async throws -> String {
        try await generateCommitMessageStreaming(context: context, config: config) { _ in }
    }

    func generateCommitMessageStreaming(
        context: GitContext,
        config: GCMConfiguration,
        onToken: @escaping StreamCallback
    ) async throws -> String {
        guard let apiKey = getApiKey() else {
            throw AIBackendError.apiKeyMissing
        }

        let apiUrl = getApiUrl(config: config)
        let model = getModel(config: config)

        let promptBuilder = PromptBuilder(config: config)
        let systemPrompt = promptBuilder.buildSystemPrompt()
        let userPrompt = promptBuilder.buildPrompt(for: context)

        let request = try buildRequest(
            apiUrl: apiUrl,
            apiKey: apiKey,
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            stream: true
        )

        var fullContent = ""

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIBackendError.invalidResponse("Not an HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Collect error body
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorBody = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AIBackendError.invalidResponse("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        // Process SSE stream
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))

            if jsonStr == "[DONE]" { break }

            guard let data = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }

            fullContent += content
            onToken(content)
        }

        return cleanCommitMessage(fullContent)
    }

    // MARK: - Private Helpers

    private func getApiKey() -> String? {
        ProcessInfo.processInfo.environment["GCM_API_KEY"]
    }

    private func getApiUrl(config: GCMConfiguration) -> String {
        config.apiUrl
            ?? ProcessInfo.processInfo.environment["GCM_API_URL"]
            ?? defaultApiUrl
    }

    private func getModel(config: GCMConfiguration) -> String {
        config.model
            ?? ProcessInfo.processInfo.environment["GCM_MODEL"]
            ?? defaultModel
    }

    private func buildRequest(
        apiUrl: String,
        apiKey: String,
        model: String,
        systemPrompt: String,
        userPrompt: String,
        stream: Bool = false
    ) throws -> URLRequest {
        guard let url = URL(string: apiUrl) else {
            throw AIBackendError.invalidResponse("Invalid API URL: \(apiUrl)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("gcm-cli", forHTTPHeaderField: "X-Title")
        request.addValue("https://github.com/gcm-cli", forHTTPHeaderField: "HTTP-Referer")

        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 500,
            "temperature": 0.3
        ]

        if stream {
            body["stream"] = true
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    func refineMessage(
        draft: String,
        context: GitContext,
        config: GCMConfiguration,
        issues: [ValidationIssue]
    ) async throws -> String {
        guard let apiKey = getApiKey() else {
            throw AIBackendError.apiKeyMissing
        }

        let refinementPrompt = buildRefinementPrompt(draft: draft, context: context, config: config, issues: issues)
        let systemPrompt = """
        You are a commit message editor. Fix specific issues while preserving core meaning.
        Output ONLY the revised commit message in conventional format: type(scope): description
        Be precise and concise.
        """

        let request = try buildRequest(
            apiUrl: getApiUrl(config: config),
            apiKey: apiKey,
            model: getModel(config: config),
            systemPrompt: systemPrompt,
            userPrompt: refinementPrompt,
            stream: false
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return draft // Fallback to draft on error
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return draft
        }

        return cleanCommitMessage(content)
    }

    private func buildRefinementPrompt(draft: String, context: GitContext, config: GCMConfiguration, issues: [ValidationIssue]) -> String {
        var prompt = "DRAFT MESSAGE:\n\(draft)\n\nISSUES FOUND:\n"

        for issue in issues {
            prompt += "- \(issue.description)\n"
        }

        let primaryCat = determinePrimaryCategory(context.categorizedFiles)
        let topFiles = Array(context.fileStats.sorted { $0.totalChanges > $1.totalChanges }.prefix(3))

        let maxLen = config.maxLength
        prompt += """

        CONTEXT REMINDER:
        - Primary category: \(primaryCat.rawValue) (\(context.categorizedFiles.count(for: primaryCat)) files)
        - Key files: \(topFiles.map { $0.path }.joined(separator: ", "))

        TASK: Revise the commit message to fix all issues above.
        Keep under \(maxLen) characters.
        Output ONLY the revised message.
        """

        return prompt
    }

    private func determinePrimaryCategory(_ categorized: CategorizedFiles) -> FileCategory {
        let counts = [
            (FileCategory.code, categorized.code.count),
            (FileCategory.test, categorized.tests.count),
            (FileCategory.doc, categorized.docs.count),
            (FileCategory.config, categorized.config.count),
            (FileCategory.other, categorized.other.count)
        ]
        return counts.max(by: { $0.1 < $1.1 })?.0 ?? .other
    }

    private func cleanCommitMessage(_ message: String) -> String {
        var cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove surrounding quotes if present
        if (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) ||
           (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) {
            cleaned = String(cleaned.dropFirst().dropLast())
        }

        // Remove markdown code block if present
        if cleaned.hasPrefix("```") {
            let lines = cleaned.split(separator: "\n", omittingEmptySubsequences: false)
            let filtered = lines.filter { !$0.hasPrefix("```") }
            cleaned = filtered.joined(separator: "\n")
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
