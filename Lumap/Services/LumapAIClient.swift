import Foundation

enum ProviderAPIStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case openAIChat
    case openAIResponses
    case anthropicMessages

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openAIChat: "OpenAI-compatible Chat"
        case .openAIResponses: "OpenAI Responses"
        case .anthropicMessages: "Anthropic Messages"
        }
    }
}

struct ProviderConfiguration: Sendable, Equatable {
    let endpoint: String
    let model: String
    let style: ProviderAPIStyle
    let apiKey: String
}

enum LumapAIError: LocalizedError, Equatable {
    case invalidEndpoint
    case insecureEndpointWithAPIKey
    case incompleteConfiguration
    case emptyPrompt
    case rejected(Int, String)
    case invalidResponse
    case incompleteResponse(String)
    case generationTimedOut(Int)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "The endpoint is not a valid HTTP or HTTPS URL."
        case .insecureEndpointWithAPIKey:
            "Use HTTPS when sending an API key. HTTP is allowed only for loopback endpoints such as localhost or 127.0.0.1."
        case .incompleteConfiguration:
            "Add a model name and API key, or use a local endpoint that does not require a key."
        case .emptyPrompt:
            "The model request cannot be empty."
        case .rejected(let code, let detail):
            "Provider returned HTTP \(code): \(detail)"
        case .invalidResponse:
            "The provider returned a successful response without readable generated text."
        case .incompleteResponse(let detail):
            "The provider stopped before completing the lesson (\(detail)). Retry with a shorter lesson or a higher output limit."
        case .generationTimedOut(let seconds):
            "The model did not finish within \(seconds) seconds. Your saved progress is safe. Please retry the activity."
        }
    }
}

enum LumapAIClient {
    /// A conventional product identifier avoids looking like an automated or
    /// anonymous client to provider gateways while revealing no learner data.
    static let userAgent = "Lumap/0.1.0 (Apple; Education App)"

    static func test(configuration: ProviderConfiguration) async throws -> String {
        let text = try await generateText(
            configuration: configuration,
            prompt: "Reply with exactly: Lumap connected",
            instructions: "Return only the requested short connection-test phrase.",
            maxOutputTokens: 24
        )
        return String(text.prefix(80))
    }

    /// Reusable text-generation boundary for every Lumap model-powered module.
    /// A base URL such as `https://provider.example/v1` is resolved to the
    /// selected protocol's concrete generation route before the request is sent.
    static func generateText(
        configuration: ProviderConfiguration,
        prompt: String,
        instructions: String? = nil,
        maxOutputTokens: Int = 2_000,
        timeoutSeconds: TimeInterval = 180,
        session: URLSession = .shared
    ) async throws -> String {
        var request = try makeRequest(
            configuration: configuration,
            prompt: prompt,
            instructions: instructions,
            maxOutputTokens: maxOutputTokens
        )
        try Task.checkCancellation()
        let deadline = min(180, max(0.05, timeoutSeconds))
        request.timeoutInterval = deadline
        let timedRequest = request
        // URLRequest.timeoutInterval is an idle timeout. Race a wall-clock
        // deadline as well so a slowly streaming gateway cannot leave Preparing
        // visible indefinitely. Cancellation propagates to URLSession.
        let (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            group.addTask { try await session.data(for: timedRequest) }
            group.addTask {
                try await Task.sleep(for: .seconds(deadline))
                throw LumapAIError.generationTimedOut(Int(ceil(deadline)))
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw LumapAIError.invalidResponse }
            return result
        }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else {
            throw LumapAIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            var detail = providerErrorMessage(from: data)
            if !configuration.apiKey.isEmpty { detail = detail.replacingOccurrences(of: configuration.apiKey, with: "[redacted]") }
            throw LumapAIError.rejected(http.statusCode, detail)
        }
        guard data.count <= 2_000_000 else { throw LumapAIError.invalidResponse }
        return try parseGeneratedText(from: data, style: configuration.style)
    }

    /// Kept internal so endpoint resolution can be regression-tested without
    /// making a network request.
    static func resolvedEndpoint(for configuration: ProviderConfiguration) throws -> URL {
        let rawEndpoint = configuration.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: rawEndpoint),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.percentEncodedQuery == nil,
              components.fragment == nil else {
            throw LumapAIError.invalidEndpoint
        }

        if scheme == "http", !configuration.apiKey.isEmpty, !isLoopback(host: host) {
            throw LumapAIError.insecureEndpointWithAPIKey
        }

        var path = components.percentEncodedPath
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        let lowercasedPath = path.lowercased()

        let knownSuffixes = ["/chat/completions", "/responses", "/messages"]
        if let suffix = knownSuffixes.first(where: { lowercasedPath.hasSuffix($0) }) {
            path.removeLast(suffix.count)
            while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        }

        if path.isEmpty || path == "/" {
            path = "/v1"
        }

        switch configuration.style {
        case .openAIChat:
            path += "/chat/completions"
        case .openAIResponses:
            path += "/responses"
        case .anthropicMessages:
            path += "/messages"
        }
        components.percentEncodedPath = path

        guard let url = components.url else { throw LumapAIError.invalidEndpoint }
        return url
    }

    /// Kept internal for deterministic response-fixture tests.
    static func parseGeneratedText(from data: Data, style: ProviderAPIStyle) throws -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LumapAIError.invalidResponse
        }

        let text: String?
        switch style {
        case .openAIChat:
            let firstChoice = (object["choices"] as? [[String: Any]])?.first
            if firstChoice?["finish_reason"] as? String == "length" {
                throw LumapAIError.incompleteResponse("output token limit")
            }
            let content = (firstChoice?["message"] as? [String: Any])?["content"]
            if let content = content as? String {
                text = content
            } else if let blocks = content as? [[String: Any]] {
                text = blocks.compactMap { $0["text"] as? String }.joined(separator: "\n")
            } else {
                text = firstChoice?["text"] as? String
            }

        case .openAIResponses:
            if object["status"] as? String == "incomplete" {
                let reason = (object["incomplete_details"] as? [String: Any])?["reason"] as? String ?? "incomplete response"
                throw LumapAIError.incompleteResponse(String(reason.prefix(100)))
            }
            if ["failed", "cancelled", "in_progress", "queued"].contains(object["status"] as? String ?? "") {
                throw LumapAIError.invalidResponse
            }
            if let outputText = object["output_text"] as? String, !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = outputText
            } else {
                text = (object["output"] as? [[String: Any]])?
                    .flatMap { $0["content"] as? [[String: Any]] ?? [] }
                    .compactMap { block in
                        block["text"] as? String ?? (block["output_text"] as? String)
                    }
                    .joined(separator: "\n")
            }

        case .anthropicMessages:
            if object["stop_reason"] as? String == "max_tokens" {
                throw LumapAIError.incompleteResponse("output token limit")
            }
            text = (object["content"] as? [[String: Any]])?
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
        }

        guard let cleaned = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !cleaned.isEmpty else {
            throw LumapAIError.invalidResponse
        }
        return cleaned
    }

    /// Kept internal so headers and request shape can be tested with dummy keys.
    static func makeRequest(
        configuration: ProviderConfiguration,
        prompt: String,
        instructions: String?,
        maxOutputTokens: Int
    ) throws -> URLRequest {
        let cleanModel = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanModel.isEmpty else { throw LumapAIError.incompleteConfiguration }
        guard !cleanPrompt.isEmpty else { throw LumapAIError.emptyPrompt }

        let url = try resolvedEndpoint(for: configuration)
        if !isLoopback(host: url.host ?? ""), configuration.apiKey.isEmpty {
            throw LumapAIError.incompleteConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Research-backed curricula and full slide narration take longer than a
        // connection probe, especially with reasoning models behind a gateway.
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        if !configuration.apiKey.isEmpty {
            switch configuration.style {
            case .anthropicMessages:
                request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            case .openAIChat, .openAIResponses:
                request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
            }
        }

        let tokenLimit = min(16_000, max(16, maxOutputTokens))
        var payload: [String: Any]
        switch configuration.style {
        case .openAIChat:
            var messages: [[String: String]] = []
            if let instructions = instructions?.trimmingCharacters(in: .whitespacesAndNewlines),
               !instructions.isEmpty {
                messages.append(["role": "developer", "content": instructions])
            }
            messages.append(["role": "user", "content": cleanPrompt])
            payload = [
                "model": cleanModel,
                "messages": messages,
                "max_tokens": tokenLimit
            ]

        case .openAIResponses:
            payload = [
                "model": cleanModel,
                "input": cleanPrompt,
                "max_output_tokens": tokenLimit
            ]
            // GPT-5.6 Sol documents `low` reasoning (not `minimal`) and text
            // verbosity. Limit this latency tuning to the configured demo
            // gateway/model pair; custom providers may reject these fields.
            // Prompt/schema requirements still govern full scripts and lessons.
            // https://developers.openai.com/api/docs/models/gpt-5.6-sol
            if url.host?.lowercased() == "api.ikuncode.cc", cleanModel == "gpt-5.6-sol" {
                payload["reasoning"] = ["effort": "low"]
                payload["text"] = ["verbosity": "low"]
            }
            if let instructions = instructions?.trimmingCharacters(in: .whitespacesAndNewlines),
               !instructions.isEmpty {
                payload["instructions"] = instructions
            }

        case .anthropicMessages:
            payload = [
                "model": cleanModel,
                "messages": [["role": "user", "content": cleanPrompt]],
                "max_tokens": tokenLimit
            ]
            if let instructions = instructions?.trimmingCharacters(in: .whitespacesAndNewlines),
               !instructions.isEmpty {
                payload["system"] = instructions
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }

    private static func providerErrorMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = object["error"] as? [String: Any],
               let message = error["message"] as? String {
                return concise(message)
            }
            if let error = object["error"] as? String { return concise(error) }
            if let message = object["message"] as? String { return concise(message) }
            if let detail = object["detail"] as? String { return concise(detail) }
        }
        return concise(String(data: data, encoding: .utf8) ?? "No response body")
    }

    private static func concise(_ value: String) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? "No response body" : String(collapsed.prefix(240))
    }

    private static func isLoopback(host: String) -> Bool {
        let normalized = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        if normalized == "localhost" || normalized.hasSuffix(".localhost") {
            return true
        }
        if normalized == "::1" || normalized == "0:0:0:0:0:0:0:1" {
            return true
        }

        let octets = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4,
              octets.allSatisfy({ component in
                  guard let value = Int(component) else { return false }
                  return (0...255).contains(value)
              }) else { return false }
        return octets[0] == "127"
    }
}
