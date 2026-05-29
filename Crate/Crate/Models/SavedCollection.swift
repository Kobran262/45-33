import Foundation
import SwiftData

enum CollectionFilterType: String, Codable, CaseIterable {
    case tag, genre, artist, label, decade, favorite
}

@Model
final class SavedCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var filterTypeRaw: String
    var filterValue: String
    var createdAt: Date

    var filterType: CollectionFilterType {
        get { CollectionFilterType(rawValue: filterTypeRaw) ?? .tag }
        set { filterTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        filterType: CollectionFilterType,
        filterValue: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.filterTypeRaw = filterType.rawValue
        self.filterValue = filterValue
        self.createdAt = createdAt
    }

    func matches(_ record: VinylRecord) -> Bool {
        switch filterType {
        case .favorite:
            return record.isFavorite
        case .tag:
            if filterValue.hasPrefix("винил:") {
                let color = String(filterValue.dropFirst(6))
                return record.vinylColorRaw == color
            }
            return record.tags.contains(filterValue)
        case .genre:
            return record.tags.contains { $0.localizedCaseInsensitiveContains(filterValue) }
        case .artist:
            return record.artist.localizedCaseInsensitiveCompare(filterValue) == .orderedSame
        case .label:
            return record.label.localizedCaseInsensitiveCompare(filterValue) == .orderedSame
        case .decade:
            let decade = (record.year / 10) * 10
            return String(decade) == filterValue
        }
    }
}
