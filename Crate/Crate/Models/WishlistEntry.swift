import Foundation
import SwiftData

@Model
final class WishlistEntry {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var year: Int?
    var note: String
    var addedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        year: Int? = nil,
        note: String = "",
        addedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.note = note
        self.addedAt = addedAt
    }
}
