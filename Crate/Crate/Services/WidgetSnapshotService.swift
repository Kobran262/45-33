import Foundation
import WidgetKit

struct WidgetRecordSnapshot: Codable, Identifiable {
    var id: UUID
    var title: String
    var artist: String
    var coverColorHex: String
    var photoDataBase64: String?
    var addedAt: Date
}

enum WidgetSnapshotService {
    static let appGroupID = "group.com.crate.vinyl"
    static let storageKey = "recentRecordSnapshots"

    static func update(records: [VinylRecord]) {
        let snapshots = records
            .sorted { $0.addedAt > $1.addedAt }
            .prefix(4)
            .map {
                WidgetRecordSnapshot(
                    id: $0.id,
                    title: $0.title,
                    artist: $0.artist,
                    coverColorHex: $0.coverColorHex,
                    photoDataBase64: $0.photoData?.base64EncodedString(),
                    addedAt: $0.addedAt
                )
            }

        guard let data = try? JSONEncoder().encode(Array(snapshots)) else { return }
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        defaults.set(data, forKey: storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
