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
    var id: UUID = UUID()
    var syncID: String = UUID().uuidString
    var name: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var address: String = ""
    var note: String = ""
    var sourceRaw: String = "user"
    var syncStatusRaw: String = VinylStoreSyncStatus.pendingUpload.rawValue
    var createdByDeviceID: String = DeviceIdentity.current
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false

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
