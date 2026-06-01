import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String = "Коллекционер"
    var handle: String = "collector"
    var memberSince: Int = Calendar.current.component(.year, from: .now)
    var avatarLetter: String = "K"
    var isPremium: Bool = false
    var defaultShowcaseStyle: Int = 0

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
