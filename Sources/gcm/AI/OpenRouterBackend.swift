import Foundation

/// AI backend using OpenRouter or OpenAI-compatible APIs
final class OpenRouterBackend: AIBackend {

    private let defaultApiUrl = "https://openrouter.ai/api/v1/chat/completions"
    private let defaultModel = "anthropic/claude-3.5-sonnet"

    var name: String { "OpenRouter API" }

    var isAvailable: Bool {
        get async {
            // Available if API key is set
            return getApiKey() != nil
        }
    }

    func generateCommitMessage(
        context: GitContext,
        config: GCMConfiguration
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
            userPrompt: userPrompt
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIBackendError.invalidResponse("Not an HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIBackendError.invalidResponse("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        return try parseResponse(data)
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
        userPrompt: String
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

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ],
            "max_tokens": 500,
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func parseResponse(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIBackendError.invalidResponse("Could not parse JSON response")
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            // Check for error message
            if let error = json["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                throw AIBackendError.generationFailed(errorMessage)
            }
            throw AIBackendError.invalidResponse("Could not extract message content from response")
        }

        return cleanCommitMessage(content)
    }

    /// Clean up the commit message (remove quotes, markdown, etc.)
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
