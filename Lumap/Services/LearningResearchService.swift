import Foundation
import Darwin

/// Small, credential-free research layer. Search queries contain only the stated
/// topic; personal profiles, uploaded text and provider keys are never sent here.
nonisolated enum LearningResearchService {
    static let maximumBytes = 1_500_000
    static let maximumExcerptCharacters = 7_000

    static func research(
        goal: String,
        language: String = "en",
        session: URLSession = .shared,
        progress: @Sendable (String) async -> Void = { _ in }
    ) async throws -> [LearningSource] {
        let query = normalizedQuery(goal)
        guard !query.isEmpty else { throw LearningAgentError.emptyGoal }
        await progress("Searching public learning sources…")
        // Independent providers improve reliability when one search service blocks requests.
        async let wiki = wikipedia(query: query, language: language, session: session)
        async let web = webSearch(query: query, session: session)
        var sources = await (wiki + web)
        try Task.checkCancellation()
        var seen = Set<String>()
        sources = sources.filter { seen.insert($0.url).inserted }
        guard !sources.isEmpty else { throw LearningAgentError.noSources }
        await progress("Read \(sources.count) sources. Planning your learning path…")
        // Deterministic source IDs make model citation validation straightforward.
        return sources.prefix(5).enumerated().map { index, source in
            LearningSource(id: "S\(index + 1)", title: source.title, url: source.url,
                           excerpt: source.excerpt, retrievedAt: source.retrievedAt)
        }
    }

    static func fetchPage(url: URL, session: URLSession = .shared) async throws -> LearningSource {
        let (data, finalURL, mime) = try await fetch(url, session: session)
        guard mime.contains("html") || mime.contains("text/plain") || mime.contains("xhtml") else {
            throw LearningAgentError.unreadableSource
        }
        guard let raw = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw LearningAgentError.unreadableSource
        }
        let title = capture("(?is)<title[^>]*>(.*?)</title>", in: raw).first.map(plainText)
        // Prefer the article itself to navigation, related links and cookie text.
        let article = capture("(?is)<main\\b[^>]*>(.*?)</main>", in: raw).max(by: { $0.count < $1.count })
            ?? capture("(?is)<article\\b[^>]*>(.*?)</article>", in: raw).max(by: { $0.count < $1.count })
        let body = plainText(article ?? raw)
        guard body.count >= 180 else { throw LearningAgentError.unreadableSource }
        // A challenge/login page is not usable learning evidence.
        let opening = body.prefix(500).lowercased()
        guard !["verify you are human", "checking your browser", "enable javascript and cookies to continue", "access denied"].contains(where: opening.contains) else {
            throw LearningAgentError.unreadableSource
        }
        return LearningSource(id: UUID().uuidString, title: String((title ?? finalURL.host ?? "Web source").prefix(180)),
                              url: finalURL.absoluteString, excerpt: String(body.prefix(maximumExcerptCharacters)), retrievedAt: .now)
    }

    static func normalizedQuery(_ goal: String) -> String {
        var query = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        for pattern in ["(?i)^(?:i\\s+)?(?:want\\s+to\\s+learn|would\\s+like\\s+to\\s+learn|teach\\s+me|learn)\\s+", "^(?:我想要学|我想学习|我想学|想要学习|想学习|想学|教我|学习)\\s*"] {
            query = query.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(180))
    }

    /// Public for tests. Literal IPs are disallowed altogether; DNS is checked
    /// separately before fetching and again before following redirects.
    nonisolated static func isAllowedPublicURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              url.user == nil, url.password == nil,
              let host = url.host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              !host.isEmpty, host.contains("."), !host.contains(":"),
              url.port == nil || url.port == 80 || url.port == 443,
              !host.split(separator: ".").allSatisfy({ Int($0) != nil }),
              !["localhost", "local", "internal", "lan", "home", "test", "invalid"].contains(where: { host == $0 || host.hasSuffix("." + $0) }) else { return false }
        return host.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-.").contains($0) }
    }

    private static func webSearch(query: String, session: URLSession) async -> [LearningSource] {
        do {
            var components = URLComponents(string: "https://html.duckduckgo.com/html/")!
            components.queryItems = [URLQueryItem(name: "q", value: query + " explanation tutorial")]
            let (data, _, _) = try await fetch(components.url!, session: session)
            let html = String(data: data, encoding: .utf8) ?? ""
            let hrefs = capture("(?is)<a\\b[^>]*class=[\"'][^\"']*result__a[^\"']*[\"'][^>]*href=[\"']([^\"']+)", in: html)
                + capture("(?is)<a\\b[^>]*href=[\"']([^\"']+)[\"'][^>]*class=[\"'][^\"']*result__a", in: html)
            var seen = Set<String>()
            let urls = hrefs.compactMap { href -> URL? in
                let decoded = decodeEntities(href)
                guard let link = URL(string: decoded.hasPrefix("//") ? "https:" + decoded : decoded, relativeTo: components.url)?.absoluteURL else { return nil }
                let unwrapped = URLComponents(url: link, resolvingAgainstBaseURL: true)?.queryItems?.first(where: { $0.name == "uddg" })?.value
                let candidate = unwrapped.flatMap(URL.init(string:)) ?? link
                let host = candidate.host?.lowercased() ?? ""
                guard isAllowedPublicURL(candidate), candidate.host?.hasSuffix("duckduckgo.com") != true,
                      !["youtube.com", "youtu.be", "tiktok.com", "vimeo.com", "instagram.com"].contains(where: { host == $0 || host.hasSuffix("." + $0) }),
                      !candidate.path.lowercased().hasSuffix(".pdf"), seen.insert(candidate.absoluteString).inserted else { return nil }
                return candidate
            }
            return await withTaskGroup(of: LearningSource?.self) { group in
                for url in urls.prefix(4) {
                    group.addTask { try? await fetchPage(url: url, session: session) }
                }
                var results: [LearningSource] = []
                for await source in group { if let source { results.append(source) } }
                return results.sorted { $0.url < $1.url }
            }
        } catch { return [] }
    }

    private static func wikipedia(query: String, language: String, session: URLSession) async -> [LearningSource] {
        let lang = language.lowercased().hasPrefix("zh") || query.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains(Int($0.value)) }) ? "zh" : "en"
        do {
            var components = URLComponents(string: "https://\(lang).wikipedia.org/w/api.php")!
            components.queryItems = [
                URLQueryItem(name: "action", value: "query"), URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "generator", value: "search"), URLQueryItem(name: "gsrsearch", value: query),
                URLQueryItem(name: "gsrlimit", value: "3"), URLQueryItem(name: "prop", value: "extracts|info"),
                URLQueryItem(name: "explaintext", value: "1"), URLQueryItem(name: "exchars", value: "1200"),
                URLQueryItem(name: "exlimit", value: "3"),
                URLQueryItem(name: "exintro", value: "1"),
                URLQueryItem(name: "inprop", value: "url"), URLQueryItem(name: "redirects", value: "1")
            ]
            let (data, _, _) = try await fetch(components.url!, session: session)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["query"] as? [String: Any], let pages = result["pages"] as? [String: [String: Any]] else { return [] }
            return pages.values.sorted { ($0["index"] as? Int ?? 100) < ($1["index"] as? Int ?? 100) }.compactMap { page in
                guard let title = page["title"] as? String, !title.lowercased().contains("disambiguation"), let excerpt = page["extract"] as? String, excerpt.count >= 180,
                      let rawURL = page["fullurl"] as? String, let url = URL(string: rawURL), isAllowedPublicURL(url) else { return nil }
                return LearningSource(id: UUID().uuidString, title: title, url: rawURL,
                                      excerpt: String(excerpt.prefix(maximumExcerptCharacters)), retrievedAt: .now)
            }
        } catch { return [] }
    }

    private static func fetch(_ url: URL, session: URLSession) async throws -> (Data, URL, String) {
        try await withThrowingTaskGroup(of: (Data, URL, String).self) { group in
            group.addTask { try await fetchBody(url, session: session) }
            group.addTask {
                try await Task.sleep(for: .seconds(25))
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw LearningAgentError.unreadableSource }
            return result
        }
    }

    private static func fetchBody(_ url: URL, session: URLSession) async throws -> (Data, URL, String) {
        try Task.checkCancellation()
        guard isAllowedPublicURL(url), await resolvesPublicly(url) else { throw LearningAgentError.blockedURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Lumap/0.2 (Learning research; https://github.com/Ar1haraNaN7mI/voiceclass)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/json,text/plain;q=0.9", forHTTPHeaderField: "Accept")
        let delegate = ResearchRedirectGuard()
        let (bytes, response) = try await session.bytes(for: request, delegate: delegate)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let finalURL = http.url, isAllowedPublicURL(finalURL) else { throw LearningAgentError.unreadableSource }
        guard response.expectedContentLength <= Int64(maximumBytes) else { throw LearningAgentError.oversizedResponse }
        var data = Data()
        let deadline = Date().addingTimeInterval(22)
        for try await byte in bytes {
            if data.count.isMultiple(of: 8192) {
                try Task.checkCancellation()
                guard Date() < deadline else { throw URLError(.timedOut) }
            }
            guard data.count < maximumBytes else { throw LearningAgentError.oversizedResponse }
            data.append(byte)
        }
        return (data, finalURL, response.mimeType ?? "text/html")
    }

    fileprivate static func resolvesPublicly(_ url: URL) async -> Bool {
        guard let host = url.host, isAllowedPublicURL(url) else { return false }
        return await Task.detached(priority: .utility) { publicDNS(host: host) }.value
    }

    nonisolated private static func publicDNS(host: String) -> Bool {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else { return false }
        defer { freeaddrinfo(first) }
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        var found = false
        while let entry = cursor {
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(entry.pointee.ai_addr, entry.pointee.ai_addrlen, &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                let address = String(decoding: buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self).lowercased()
                if address.contains(":") {
                    if address == "::" || address == "::1" || address.hasPrefix("fc") || address.hasPrefix("fd") || address.hasPrefix("fe8") || address.hasPrefix("fe9") || address.hasPrefix("fea") || address.hasPrefix("feb") || address.hasPrefix("ff") || address.hasPrefix("::ffff:") { return false }
                } else {
                    let parts = address.split(separator: ".").compactMap { Int($0) }
                    guard parts.count == 4 else { return false }
                    if parts[0] == 0 || parts[0] == 10 || parts[0] == 127 || parts[0] >= 224 ||
                        (parts[0] == 169 && parts[1] == 254) || (parts[0] == 172 && (16...31).contains(parts[1])) ||
                        (parts[0] == 192 && parts[1] == 168) || (parts[0] == 100 && (64...127).contains(parts[1])) ||
                        (parts[0] == 198 && [18, 19].contains(parts[1])) { return false }
                }
                found = true
            }
            cursor = entry.pointee.ai_next
        }
        return found
    }

    private static func capture(_ pattern: String, in value: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).compactMap {
            guard let range = Range($0.range(at: 1), in: value) else { return nil }
            return String(value[range])
        }
    }

    static func plainText(_ html: String) -> String {
        var result = html.replacingOccurrences(of: "(?is)<(script|style|nav|header|footer|noscript|svg)\\b[^>]*>.*?</\\1>", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "(?is)<[^>]+>", with: " ", options: .regularExpression)
        return decodeEntities(result).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ value: String) -> String {
        var text = value
        for (entity, replacement) in [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&nbsp;", " "), ("&mdash;", "—"), ("&ndash;", "–"), ("&hellip;", "…")] {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        let pattern = "&#(x[0-9a-fA-F]+|[0-9]+);"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
                guard let digits = Range(match.range(at: 1), in: text), let whole = Range(match.range, in: text) else { continue }
                let raw = String(text[digits])
                let number = raw.hasPrefix("x") ? UInt32(raw.dropFirst(), radix: 16) : UInt32(raw)
                if let number, let scalar = UnicodeScalar(number) { text.replaceSubrange(whole, with: String(scalar)) }
            }
        }
        return text
    }
}

private final class ResearchRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        guard let url = request.url, LearningResearchService.isAllowedPublicURL(url) else { completionHandler(nil); return }
        Task {
            let allowed = await LearningResearchService.resolvesPublicly(url)
            completionHandler(allowed ? request : nil)
        }
    }
}
