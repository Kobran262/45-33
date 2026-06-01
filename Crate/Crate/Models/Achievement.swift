import Foundation
import SwiftData

@Model
final class Achievement {
    var id: UUID = UUID()
    var kind: String = ""
    var unlockedAt: Date = Date()
    var recordIdAtUnlock: UUID?

    init(
        id: UUID = UUID(),
        kind: String,
        unlockedAt: Date = .now,
        recordIdAtUnlock: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.unlockedAt = unlockedAt
        self.recordIdAtUnlock = recordIdAtUnlock
    }
}
