import Foundation

struct VinylStoreSyncPayload: Codable, Identifiable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String
    let note: String
    let updatedAt: Date
    let isDeleted: Bool
}

protocol VinylStoreSyncService {
    func pullStores(since: Date?) async throws -> [VinylStoreSyncPayload]
    func pushStores(_ stores: [VinylStoreSyncPayload]) async throws
}

/// Локальная заглушка: UI уже работает, а сюда позже подключается CloudKit/backend.
struct NoopVinylStoreSyncService: VinylStoreSyncService {
    func pullStores(since: Date?) async throws -> [VinylStoreSyncPayload] { [] }
    func pushStores(_ stores: [VinylStoreSyncPayload]) async throws {}
}
