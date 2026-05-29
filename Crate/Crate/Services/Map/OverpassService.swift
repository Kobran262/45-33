import Foundation
import CoreLocation
import MapKit

struct VinylShop: Identifiable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let distanceMeters: Double?
    let openingHours: String?
    let osmTags: [String: String]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// OpenStreetMap через Overpass API — винил-магазины рядом.
/// Документация: https://wiki.openstreetmap.org/wiki/Overpass_API
actor OverpassService {
    static let shared = OverpassService()

    private let endpoints = [
        "https://overpass.kumi.systems/api/interpreter",
        "https://overpass-api.de/api/interpreter",
    ]

    private var cache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 10 * 60

    func fetchShopsNear(coordinate: CLLocationCoordinate2D, radiusMeters: Int = 1400) async throws -> [VinylShop] {
        let cacheKey = Self.cacheKey(coordinate: coordinate, radiusMeters: radiusMeters)
        if let entry = cache[cacheKey], Date().timeIntervalSince(entry.createdAt) < cacheTTL {
            return entry.shops
        }

        let query = buildQuery(lat: coordinate.latitude, lon: coordinate.longitude, radius: radiusMeters)
        var lastError: Error?

        for endpoint in endpoints {
            do {
                let shops = try await execute(query: query, userLocation: coordinate, endpoint: endpoint)
                cache[cacheKey] = CacheEntry(createdAt: .now, shops: shops)
                return shops
            } catch {
                if Task.isCancelled { throw error }
                lastError = error
            }
        }
        throw lastError ?? URLError(.cannotConnectToHost)
    }

    func fetchShops(in region: MKCoordinateRegion, userLocation: CLLocationCoordinate2D?) async throws -> [VinylShop] {
        let cacheKey = Self.cacheKey(region: region)
        if let entry = cache[cacheKey], Date().timeIntervalSince(entry.createdAt) < cacheTTL {
            return entry.shops
        }

        let query = buildQuery(region: region)
        let reference = userLocation ?? region.center
        var lastError: Error?

        for endpoint in endpoints {
            do {
                let shops = try await execute(query: query, userLocation: reference, endpoint: endpoint)
                cache[cacheKey] = CacheEntry(createdAt: .now, shops: shops)
                return shops
            } catch {
                if Task.isCancelled { throw error }
                lastError = error
            }
        }
        throw lastError ?? URLError(.cannotConnectToHost)
    }

    private func buildQuery(lat: Double, lon: Double, radius: Int) -> String {
        """
        [out:json][timeout:8];
        (
          node["shop"="music"]["name"~"vinyl|record|records|lp|пластинк",i](around:\(radius),\(lat),\(lon));
          node["shop"="second_hand"]["name"~"vinyl|record|пластинк",i](around:\(radius),\(lat),\(lon));
          way["shop"="music"]["name"~"vinyl|record|records|lp|пластинк",i](around:\(radius),\(lat),\(lon));
          way["shop"="second_hand"]["name"~"vinyl|record|пластинк",i](around:\(radius),\(lat),\(lon));
        );
        out center tags 40;
        """
    }

    private func buildQuery(region: MKCoordinateRegion) -> String {
        let expanded = Self.expanded(region: region)
        let south = max(-90, expanded.center.latitude - expanded.span.latitudeDelta / 2)
        let north = min(90, expanded.center.latitude + expanded.span.latitudeDelta / 2)
        let west = max(-180, expanded.center.longitude - expanded.span.longitudeDelta / 2)
        let east = min(180, expanded.center.longitude + expanded.span.longitudeDelta / 2)

        return """
        [out:json][timeout:10];
        (
          node["shop"="music"](\(south),\(west),\(north),\(east));
          way["shop"="music"](\(south),\(west),\(north),\(east));
          relation["shop"="music"](\(south),\(west),\(north),\(east));
          node["shop"~"second_hand|books|antiques"]["name"~"vinyl|record|records|lp|пластинк|винил",i](\(south),\(west),\(north),\(east));
          way["shop"~"second_hand|books|antiques"]["name"~"vinyl|record|records|lp|пластинк|винил",i](\(south),\(west),\(north),\(east));
          relation["shop"~"second_hand|books|antiques"]["name"~"vinyl|record|records|lp|пластинк|винил",i](\(south),\(west),\(north),\(east));
          node["music"~"vinyl|records",i](\(south),\(west),\(north),\(east));
          way["music"~"vinyl|records",i](\(south),\(west),\(north),\(east));
          relation["music"~"vinyl|records",i](\(south),\(west),\(north),\(east));
        );
        out center tags 120;
        """
    }

    private func execute(query: String, userLocation: CLLocationCoordinate2D, endpoint: String) async throws -> [VinylShop] {
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)".data(using: .utf8)
        req.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
        let user = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

        return decoded.elements.compactMap { el -> VinylShop? in
            let lat = el.lat ?? el.center?.lat
            let lon = el.lon ?? el.center?.lon
            guard let lat, let lon else { return nil }
            let tags = el.tags ?? [:]
            let name = tags["name"] ?? tags["brand"] ?? "Винил-магазин"
            let loc = CLLocation(latitude: lat, longitude: lon)
            return VinylShop(
                id: "\(el.type)-\(el.id)",
                name: name,
                latitude: lat,
                longitude: lon,
                address: Self.formatAddress(tags: tags),
                distanceMeters: user.distance(from: loc),
                openingHours: tags["opening_hours"],
                osmTags: tags
            )
        }
        .sorted { ($0.distanceMeters ?? .infinity) < ($1.distanceMeters ?? .infinity) }
    }

    private static func formatAddress(tags: [String: String]) -> String? {
        let parts = [tags["addr:street"], tags["addr:housenumber"], tags["addr:city"]].compactMap { $0 }
        return parts.isEmpty ? tags["addr:full"] : parts.joined(separator: " ")
    }

    private static func cacheKey(coordinate: CLLocationCoordinate2D, radiusMeters: Int) -> String {
        let latBucket = (coordinate.latitude * 100).rounded() / 100
        let lonBucket = (coordinate.longitude * 100).rounded() / 100
        return "\(latBucket):\(lonBucket):\(radiusMeters)"
    }

    private static func cacheKey(region: MKCoordinateRegion) -> String {
        let expanded = expanded(region: region)
        let latBucket = (expanded.center.latitude * 100).rounded() / 100
        let lonBucket = (expanded.center.longitude * 100).rounded() / 100
        let latSpan = (expanded.span.latitudeDelta * 100).rounded() / 100
        let lonSpan = (expanded.span.longitudeDelta * 100).rounded() / 100
        return "bbox:\(latBucket):\(lonBucket):\(latSpan):\(lonSpan)"
    }

    private static func expanded(region: MKCoordinateRegion) -> MKCoordinateRegion {
        let paddedLatitudeDelta = max(region.span.latitudeDelta * 1.8, 0.035)
        let paddedLongitudeDelta = max(region.span.longitudeDelta * 1.8, 0.035)
        return MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(latitudeDelta: paddedLatitudeDelta, longitudeDelta: paddedLongitudeDelta)
        )
    }
}

private struct CacheEntry {
    let createdAt: Date
    let shops: [VinylShop]
}

private struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

private struct OverpassElement: Decodable {
    let type: String
    let id: Int
    let lat: Double?
    let lon: Double?
    let center: OverpassCenter?
    let tags: [String: String]?
}

private struct OverpassCenter: Decodable {
    let lat: Double
    let lon: Double
}
