import Foundation
import SwiftData

enum VinylColor: String, Codable, CaseIterable {
    case black, clear, red, gold, marble, splatter

    var label: String {
        switch self {
        case .black: "чёрный"
        case .clear: "прозрачный"
        case .red: "красный"
        case .gold: "золотой"
        case .marble: "мрамор"
        case .splatter: "сплэттер"
        }
    }
}

enum RecordGrade: String, Codable, CaseIterable {
    case VG, VGPlus = "VG+", NM, M

    var display: String { rawValue }
}

@Model
final class VinylRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var year: Int
    var coverColorHex: String
    @Attribute(.externalStorage) var photoData: Data?
    var vinylColorRaw: String
    var gradeRaw: String
    var price: Double
    var currency: String
    var pressing: String
    var label: String
    var tags: [String]
    var isFavorite: Bool
    var story: String
    var addedAt: Date
    /// ID релиза в Discogs (если добавлено через API)
    var discogsReleaseId: Int?

    var vinylColor: VinylColor {
        get { VinylColor(rawValue: vinylColorRaw) ?? .black }
        set { vinylColorRaw = newValue.rawValue }
    }

    var grade: RecordGrade {
        get { RecordGrade(rawValue: gradeRaw) ?? .VGPlus }
        set { gradeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        year: Int,
        coverColorHex: String = "#5a4a7a",
        photoData: Data? = nil,
        vinylColor: VinylColor = .black,
        grade: RecordGrade = .VGPlus,
        price: Double = 0,
        currency: String = "€",
        pressing: String = "—",
        label: String = "—",
        tags: [String] = [],
        isFavorite: Bool = false,
        story: String = "",
        addedAt: Date = .now,
        discogsReleaseId: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.coverColorHex = coverColorHex
        self.photoData = photoData
        self.vinylColorRaw = vinylColor.rawValue
        self.gradeRaw = grade.rawValue
        self.price = price
        self.currency = currency
        self.pressing = pressing
        self.label = label
        self.tags = tags
        self.isFavorite = isFavorite
        self.story = story
        self.addedAt = addedAt
        self.discogsReleaseId = discogsReleaseId
    }

    var formattedPrice: String {
        guard price > 0 else { return "" }
        return "\(currency)\(Int(price))"
    }

    func matchesFilter(_ filter: ShelfFilter) -> Bool {
        switch filter {
        case .all: true
        case .favorite:
            isFavorite || tags.contains { $0.localizedCaseInsensitiveCompare("любимое") == .orderedSame }
        case .tag(let t):
            tags.contains { $0.localizedCaseInsensitiveCompare(t) == .orderedSame }
        case .collection(let col): col.matches(self)
        }
    }
}

enum ShelfFilter {
    case all, favorite
    case tag(String)
    case collection(SavedCollection)

    var title: String {
        switch self {
        case .all: "всё"
        case .favorite: "любимое"
        case .tag(let t): t
        case .collection(let c): c.name
        }
    }
}
