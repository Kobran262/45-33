import Foundation

struct DiscogsSearchResponse: Decodable {
    let results: [DiscogsSearchResult]
}

struct DiscogsSearchResult: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let year: String?
    let thumb: String?
    let cover_image: String?
    let resource_url: String?
    let type: String?
    let country: String?
    let label: [String]?
    let format: [String]?
    let genre: [String]?
    let style: [String]?
    let barcode: [String]?

    var parsedArtist: String {
        let parts = title.split(separator: " - ", maxSplits: 1)
        return parts.count > 1 ? String(parts[0]) : "Unknown"
    }

    var parsedAlbum: String {
        let parts = title.split(separator: " - ", maxSplits: 1)
        return parts.count > 1 ? String(parts[1]) : title
    }

    var yearInt: Int? { year.flatMap { Int($0) } }
}

struct DiscogsRelease: Decodable {
    let id: Int
    let title: String
    let year: Int?
    let artists: [DiscogsArtist]?
    let labels: [DiscogsLabel]?
    let formats: [DiscogsFormat]?
    let thumb: String?
    let images: [DiscogsImage]?
    let country: String?
    let genres: [String]?
    let styles: [String]?
    let identifiers: [DiscogsIdentifier]?

    var primaryArtist: String {
        artists?.first?.name ?? "Unknown"
    }

    var primaryLabel: String {
        labels?.first?.name ?? "—"
    }

    var formatDescription: String {
        formats?.compactMap(\.descriptions).flatMap { $0 }.prefix(2).joined(separator: " · ") ?? "—"
    }

    var primaryImageURL: String? {
        images?.first(where: { $0.type == "primary" })?.uri ?? images?.first?.uri ?? thumb
    }

    var barcodeValue: String? {
        identifiers?.first(where: { $0.type.localizedCaseInsensitiveContains("barcode") })?.value
    }
}

struct DiscogsArtist: Decodable {
    let name: String
}

struct DiscogsLabel: Decodable {
    let name: String
}

struct DiscogsFormat: Decodable {
    let descriptions: [String]?
}

struct DiscogsImage: Decodable {
    let uri: String?
    let type: String?
}

struct DiscogsIdentifier: Decodable {
    let type: String
    let value: String
}
