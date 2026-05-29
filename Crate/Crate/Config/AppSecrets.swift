import Foundation

/// Токены и ключи — не коммитить Secrets.plist в git.
enum AppSecrets {
    /// Discogs Personal Access Token
    /// Получить: https://www.discogs.com/settings/developers
    static var discogsToken: String {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let token = plist["DISCOGS_TOKEN"] as? String, !token.isEmpty, token != "YOUR_TOKEN_HERE" {
            return token
        }
        return ProcessInfo.processInfo.environment["DISCOGS_TOKEN"] ?? ""
    }

    static var hasDiscogsToken: Bool { !discogsToken.isEmpty }

    /// User-Agent обязателен для Discogs API
    static let discogsUserAgent = "45-33/1.0 +https://github.com/your-handle/45-33"
}
