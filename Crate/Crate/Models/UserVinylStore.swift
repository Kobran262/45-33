import Foundation
import SwiftData

enum VinylStoreSyncStatus: String, Codable, CaseIterable {
    case localOnly
    case pendingUpload
    case synced
    case pendingDelete
    case conflict
}

@Model
final class UserVinylStore {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var syncID: String
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

    var syncStatus: VinylStoreSyncStatus {
        get { VinylStoreSyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        syncID: String = UUID().uuidString,
        name: String,
        latitude: Double,
        longitude: Double,
        address: String = "",
        note: String = "",
        sourceRaw: String = "user",
        syncStatus: VinylStoreSyncStatus = .pendingUpload,
        createdByDeviceID: String = DeviceIdentity.current,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.syncID = syncID
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.note = note
        self.sourceRaw = sourceRaw
        self.syncStatusRaw = syncStatus.rawValue
        self.createdByDeviceID = createdByDeviceID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}

enum DeviceIdentity {
    static var current: String {
        let key = "crate.device.identity"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}
