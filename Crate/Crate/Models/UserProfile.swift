import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var handle: String
    var memberSince: Int
    var avatarLetter: String
    var isPremium: Bool
    var defaultShowcaseStyle: Int

    init(
        id: UUID = UUID(),
        name: String = "Коллекционер",
        handle: String = "collector",
        memberSince: Int = Calendar.current.component(.year, from: .now),
        avatarLetter: String = "K",
        isPremium: Bool = false,
        defaultShowcaseStyle: Int = 0
    ) {
        self.id = id
        self.name = name
        self.handle = handle
        self.memberSince = memberSince
        self.avatarLetter = avatarLetter
        self.isPremium = isPremium
        self.defaultShowcaseStyle = defaultShowcaseStyle
    }
}
