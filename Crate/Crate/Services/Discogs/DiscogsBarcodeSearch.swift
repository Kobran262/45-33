import Foundation

extension DiscogsService {
    /// Поиск релиза по штрихкоду (UPC/EAN). Discogs принимает параметр `barcode=`.
    func searchByBarcode(_ code: String) async throws -> [DiscogsSearchResult] {
        guard AppSecrets.hasDiscogsToken else { throw DiscogsError.missingToken }
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        var components = URLComponents(string: "https://api.discogs.com/database/search")!
        components.queryItems = [
            URLQueryItem(name: "barcode", value: cleaned),
            URLQueryItem(name: "type", value: "release"),
            URLQueryItem(name: "per_page", value: "10"),
        ]

        var req = URLRequest(url: components.url!)
        req.setValue(AppSecrets.discogsUserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("Discogs token=\(AppSecrets.discogsToken)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw DiscogsError.decoding }
        if http.statusCode == 429 { throw DiscogsError.rateLimited }
        guard (200...299).contains(http.statusCode) else { throw DiscogsError.httpStatus(http.statusCode) }

        return try JSONDecoder().decode(DiscogsSearchResponse.self, from: data).results
    }
}
