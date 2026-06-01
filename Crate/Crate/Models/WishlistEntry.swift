import Foundation
import SwiftData

@Model
final class WishlistEntry {
    var id: UUID = UUID()
    var title: String = ""
    var artist: String = ""
    var year: Int?
    var note: String = ""
    var priority: Int = 0
    var addedAt: Date = Date()

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        year: Int? = nil,
        note: String = "",
        priority: Int = 0,
        addedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.note = note
        self.priority = priority
        self.addedAt = addedAt
    }
}
