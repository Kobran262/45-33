import Foundation

struct AppBackup: Codable {
    var version: Int
    var exportedAt: Date
    var records: [BackupRecord]
    var wishlist: [BackupWishlistEntry]
    var collections: [BackupCollection]
    var profile: BackupProfile?
    var userStores: [BackupUserVinylStore]
    var achievements: [BackupAchievement] = []
}

struct BackupRecord: Codable {
    var id: UUID
    var title: String
    var artist: String
    var year: Int
    var coverColorHex: String
    var photoDataBase64: String?
    var vinylColorRaw: String
    var gradeRaw: String
    var price: Double
    var currency: String
    var pressing: String
    var label: String
    var tags: [String]
    var isFavorite: Bool
    var story: String
    var purchasedAt: Date?
    var purchaseLocation: String
    var addedAt: Date
    var discogsReleaseId: Int?
}

struct BackupWishlistEntry: Codable {
    var id: UUID
    var title: String
    var artist: String
    var year: Int?
    var note: String
    var addedAt: Date
}

struct BackupCollection: Codable {
    var id: UUID
    var name: String
    var filterTypeRaw: String
    var filterValue: String
    var excludedRecordIDs: [String]
    var createdAt: Date
}

struct BackupProfile: Codable {
    var id: UUID
    var name: String
    var handle: String
    var memberSince: Int
    var avatarLetter: String
    var isPremium: Bool
    var defaultShowcaseStyle: Int
}

struct BackupUserVinylStore: Codable {
    var id: UUID
    var syncID: String
    var name: String
    var latitude: Double
    var longitude: Double
    var address: String
    var note: String
    var sourceRaw: String
    var syncStatusRaw: String
    var createdByDeviceID: String
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
}

struct BackupAchievement: Codable {
    var id: UUID
    var kind: String
    var unlockedAt: Date
    var recordIdAtUnlock: UUID?
}

enum BackupService {
    static func export(
        records: [VinylRecord],
        wishlist: [WishlistEntry],
        collections: [SavedCollection],
        profile: UserProfile?,
        userStores: [UserVinylStore],
        achievements: [Achievement] = [],
        includePhotos: Bool
    ) throws -> Data {
        let backup = AppBackup(
            version: 1,
            exportedAt: .now,
            records: records.map { record in
                BackupRecord(
                    id: record.id,
                    title: record.title,
                    artist: record.artist,
                    year: record.year,
                    coverColorHex: record.coverColorHex,
                    photoDataBase64: includePhotos ? record.photoData?.base64EncodedString() : nil,
                    vinylColorRaw: record.vinylColorRaw,
                    gradeRaw: record.gradeRaw,
                    price: record.price,
                    currency: record.currency,
                    pressing: record.pressing,
                    label: record.label,
                    tags: record.tags,
                    isFavorite: record.isFavorite,
                    story: record.story,
                    purchasedAt: record.purchasedAt,
                    purchaseLocation: record.purchaseLocation,
                    addedAt: record.addedAt,
                    discogsReleaseId: record.discogsReleaseId
                )
            },
            wishlist: wishlist.map {
                BackupWishlistEntry(
                    id: $0.id,
                    title: $0.title,
                    artist: $0.artist,
                    year: $0.year,
                    note: $0.note,
                    addedAt: $0.addedAt
                )
            },
            collections: collections.map {
                BackupCollection(
                    id: $0.id,
                    name: $0.name,
                    filterTypeRaw: $0.filterTypeRaw,
                    filterValue: $0.filterValue,
                    excludedRecordIDs: $0.excludedRecordIDs,
                    createdAt: $0.createdAt
                )
            },
            profile: profile.map {
                BackupProfile(
                    id: $0.id,
                    name: $0.name,
                    handle: $0.handle,
                    memberSince: $0.memberSince,
                    avatarLetter: $0.avatarLetter,
                    isPremium: $0.isPremium,
                    defaultShowcaseStyle: $0.defaultShowcaseStyle
                )
            },
            userStores: userStores.map {
                BackupUserVinylStore(
                    id: $0.id,
                    syncID: $0.syncID,
                    name: $0.name,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    address: $0.address,
                    note: $0.note,
                    sourceRaw: $0.sourceRaw,
                    syncStatusRaw: $0.syncStatusRaw,
                    createdByDeviceID: $0.createdByDeviceID,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    isDeleted: $0.isDeleted
                )
            },
            achievements: achievements.map {
                BackupAchievement(
                    id: $0.id,
                    kind: $0.kind,
                    unlockedAt: $0.unlockedAt,
                    recordIdAtUnlock: $0.recordIdAtUnlock
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func decode(data: Data) throws -> AppBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppBackup.self, from: data)
    }
}
