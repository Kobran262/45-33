import Foundation
import SwiftData

enum AchievementService {
    static let milestoneCounts = [1, 10, 25, 50, 100, 200, 500, 1000]

    static func evaluate(
        records: [VinylRecord],
        existing: [Achievement],
        context: ModelContext,
        triggerRecord: VinylRecord? = nil
    ) -> [Achievement] {
        var unlocked: [Achievement] = []
        var existingKinds = Set(existing.map(\.kind))

        for count in milestoneCounts where records.count >= count {
            unlock(
                kind: "milestone\(count)",
                existingKinds: &existingKinds,
                context: context,
                triggerRecord: triggerRecord,
                unlocked: &unlocked
            )
        }

        for tag in Set(records.flatMap(\.tags)) where !tag.isEmpty {
            let count = records.filter { $0.tags.contains(tag) }.count
            if count >= 10 {
                unlock(
                    kind: "genre10.\(tag.lowercased())",
                    existingKinds: &existingKinds,
                    context: context,
                    triggerRecord: triggerRecord,
                    unlocked: &unlocked
                )
            } else if count >= 1 {
                unlock(
                    kind: "firstGenre.\(tag.lowercased())",
                    existingKinds: &existingKinds,
                    context: context,
                    triggerRecord: triggerRecord,
                    unlocked: &unlocked
                )
            }
        }

        let labelGroups = Dictionary(grouping: records.filter { !$0.label.isEmpty && $0.label != "—" }, by: \.label)
        for (label, records) in labelGroups where records.count >= 5 {
            unlock(
                kind: "label5.\(label.lowercased())",
                existingKinds: &existingKinds,
                context: context,
                triggerRecord: triggerRecord,
                unlocked: &unlocked
            )
        }

        let decades = Set(records.map { ($0.year / 10) * 10 }.filter { $0 > 0 })
        if decades.count >= 5 {
            unlock(
                kind: "fiveDecades",
                existingKinds: &existingKinds,
                context: context,
                triggerRecord: triggerRecord,
                unlocked: &unlocked
            )
        }

        return unlocked
    }

    static func title(for kind: String) -> String {
        if kind.hasPrefix("milestone") {
            return "Юбилей на полке"
        }
        if kind.hasPrefix("firstGenre") {
            return "Первый жанровый след"
        }
        if kind.hasPrefix("genre10") {
            return "Жанр прижился"
        }
        if kind.hasPrefix("label5") {
            return "Лейбл занял полку"
        }
        if kind == "fiveDecades" {
            return "Пять эпох"
        }
        return "Достижение"
    }

    private static func unlock(
        kind: String,
        existingKinds: inout Set<String>,
        context: ModelContext,
        triggerRecord: VinylRecord?,
        unlocked: inout [Achievement]
    ) {
        guard !existingKinds.contains(kind) else { return }
        existingKinds.insert(kind)
        let achievement = Achievement(kind: kind, recordIdAtUnlock: triggerRecord?.id)
        context.insert(achievement)
        unlocked.append(achievement)
    }
}
