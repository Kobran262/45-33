import Foundation

enum DiscogsError: LocalizedError {
    case missingToken
    case httpStatus(Int)
    case decoding
    case rateLimited
    case invalidImageURL

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Добавь DISCOGS_TOKEN в Secrets.plist (см. README-IOS.md)"
        case .httpStatus(let code):
            "Discogs ответил с кодом \(code)"
        case .decoding:
            "Не удалось разобрать ответ Discogs"
        case .rateLimited:
            "Лимит запросов Discogs — подожди минуту"
        case .invalidImageURL:
            "Не удалось скачать обложку Discogs"
        }
    }
}

/// Клиент Discogs API — на iOS CORS не нужен, запросы напрямую.
actor DiscogsService {
    static let shared = DiscogsService()

    private let session: URLSession
    private let baseURL = URL(string: "https://api.discogs.com")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchReleases(query: String, page: Int = 1) async throws -> [DiscogsSearchResult] {
        guard AppSecrets.hasDiscogsToken else { throw DiscogsError.missingToken }
        var components = URLComponents(url: baseURL.appendingPathComponent("database/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "release"),
            URLQueryItem(name: "format", value: "Vinyl"),
            URLQueryItem(name: "per_page", value: "15"),
            URLQueryItem(name: "page", value: String(page)),
        ]
        let data = try await request(url: components.url!)
        let decoded = try JSONDecoder().decode(DiscogsSearchResponse.self, from: data)
        return decoded.results
    }

    func searchArtist(name: String) async throws -> [DiscogsSearchResult] {
        guard AppSecrets.hasDiscogsToken else { throw DiscogsError.missingToken }
        var components = URLComponents(url: baseURL.appendingPathComponent("database/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "artist", value: name),
            URLQueryItem(name: "type", value: "release"),
            URLQueryItem(name: "format", value: "Vinyl"),
            URLQueryItem(name: "per_page", value: "12"),
            URLQueryItem(name: "page", value: "1"),
        ]
        let data = try await request(url: components.url!)
        let decoded = try JSONDecoder().decode(DiscogsSearchResponse.self, from: data)
        return decoded.results
    }

    func fetchRelease(id: Int) async throws -> DiscogsRelease {
        guard AppSecrets.hasDiscogsToken else { throw DiscogsError.missingToken }
        let url = baseURL.appendingPathComponent("releases/\(id)")
        let data = try await request(url: url)
        return try JSONDecoder().decode(DiscogsRelease.self, from: data)
    }

    func fetchImageData(urlString: String?) async throws -> Data? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.setValue(AppSecrets.discogsUserAgent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw DiscogsError.invalidImageURL }
        guard (200...299).contains(http.statusCode) else { throw DiscogsError.httpStatus(http.statusCode) }
        return data
    }

    nonisolated func mapToRecord(_ release: DiscogsRelease, existingTags: [String] = []) -> VinylRecord {
        VinylRecord(
            title: release.title.components(separatedBy: " - ").last ?? release.title,
            artist: release.primaryArtist,
            year: release.year ?? 1970,
            coverColorHex: Self.randomCoverHex(),
            pressing: release.formatDescription,
            label: release.primaryLabel,
            tags: existingTags.isEmpty ? Self.tags(from: release) : existingTags,
            discogsReleaseId: release.id
        )
    }

    nonisolated func mapSearchResult(_ result: DiscogsSearchResult) -> VinylRecord {
        VinylRecord(
            title: result.parsedAlbum,
            artist: result.parsedArtist,
            year: result.yearInt ?? 1970,
            coverColorHex: Self.randomCoverHex(),
            pressing: result.format?.prefix(2).joined(separator: " · ") ?? "—",
            label: result.label?.first ?? "—",
            tags: Self.tags(from: result),
            discogsReleaseId: result.id
        )
    }

    private func request(url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue(AppSecrets.discogsUserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("Discogs token=\(AppSecrets.discogsToken)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 20

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw DiscogsError.decoding }
        if http.statusCode == 429 { throw DiscogsError.rateLimited }
        guard (200...299).contains(http.statusCode) else { throw DiscogsError.httpStatus(http.statusCode) }
        return data
    }

    private static func randomCoverHex() -> String {
        ["#b8472b", "#2f5d6e", "#7a6a3a", "#9c3d52", "#3a5536", "#a8632c", "#5a4a7a"].randomElement()!
    }

    private static func tags(from release: DiscogsRelease) -> [String] {
        let source = (release.genres ?? []) + (release.styles ?? [])
        return Array(source.prefix(4)).map { $0.lowercased() }
    }

    private static func tags(from result: DiscogsSearchResult) -> [String] {
        let source = (result.genre ?? []) + (result.style ?? [])
        return Array(source.prefix(4)).map { $0.lowercased() }
    }
}
