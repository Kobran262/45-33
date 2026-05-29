import Foundation
import SwiftData

struct CollectionSuggestion: Identifiable {
    let id: String
    let title: String
    let body: String
    let filterType: CollectionFilterType
    let filterValue: String
}

enum SuggestionsEngine {
    private static let minCount = 3
    private static let shelfPromptMinCount = 5

    static func compute(records: [VinylRecord], existing: [SavedCollection]) -> [CollectionSuggestion] {
        var out: [CollectionSuggestion] = []
        let has: (CollectionFilterType, String) -> Bool = { type, value in
            existing.contains { $0.filterType == type && $0.filterValue.lowercased() == value.lowercased() }
        }

        let jazz = records.filter { $0.tags.contains { $0.localizedCaseInsensitiveContains("джаз") } }
        if jazz.count >= minCount, !has(.genre, "джаз") {
            out.append(.init(id: "jazz", title: "Джаз-полка",
                             body: "\(jazz.count) пластинок жанра «джаз» — собрать в коллекцию?",
                             filterType: .genre, filterValue: "джаз"))
        }

        var byArtist: [String: Int] = [:]
        records.forEach { byArtist[$0.artist, default: 0] += 1 }
        if let top = byArtist.max(by: { $0.value < $1.value }), top.value >= minCount, !has(.artist, top.key) {
            out.append(.init(id: "artist", title: top.key,
                             body: "\(top.value) пластинок \(top.key). Собираешь дискографию?",
                             filterType: .artist, filterValue: top.key))
        }

        var byDecade: [Int: Int] = [:]
        records.forEach {
            let d = ($0.year / 10) * 10
            byDecade[d, default: 0] += 1
        }
        if let top = byDecade.max(by: { $0.value < $1.value }), top.value >= minCount, !has(.decade, String(top.key)) {
            out.append(.init(id: "decade", title: "\(top.key)-е",
                             body: "\(top.value) пластинок \(top.key)-е. Эпоха явно зацепила — собрать вместе?",
                             filterType: .decade, filterValue: String(top.key)))
        }

        let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let recent = records.filter { $0.addedAt >= monthAgo }
        if recent.count >= minCount, !has(.tag, "недавние") {
            out.append(.init(id: "recent", title: "Свежие находки",
                             body: "\(recent.count) пластинок за последний месяц. Посмотреть как «Новинки»?",
                             filterType: .tag, filterValue: "недавние"))
        }

        return Array(out.prefix(3))
    }

    static func shelfPrompt(records: [VinylRecord], existing: [SavedCollection], ignoredIDs: Set<String>) -> CollectionSuggestion? {
        let has: (CollectionFilterType, String) -> Bool = { type, value in
            existing.contains { collection in
                let sameValue = collection.filterValue.localizedCaseInsensitiveCompare(value) == .orderedSame
                if type == .genre {
                    return sameValue && (collection.filterType == .genre || collection.filterType == .tag)
                }
                return sameValue && collection.filterType == type
            }
        }

        var candidates: [CollectionSuggestion] = []

        for (label, count) in grouped(records.map(\.label)) where count >= shelfPromptMinCount {
            let id = "label:\(label.lowercased())"
            if !ignoredIDs.contains(id), !has(.label, label) {
                candidates.append(.init(
                    id: id,
                    title: label,
                    body: randomPrompt(
                        type: "лейбла",
                        value: label,
                        count: count,
                        variants: [
                            "{N} пластинок {VALUE}. Лейбл явно поселился на полке — выделим ему комнату?",
                            "{VALUE} уже на {N} релизов. Это не случайность, это маленькая штаб-квартира.",
                            "{N} раз {VALUE}. Похоже, лейбл пришёл не в гости — сделать коллекцию?"
                        ]
                    ),
                    filterType: .label,
                    filterValue: label
                ))
            }
        }

        for (artist, count) in grouped(records.map(\.artist)) where count >= shelfPromptMinCount {
            let id = "artist:\(artist.lowercased())"
            if !ignoredIDs.contains(id), !has(.artist, artist) {
                candidates.append(.init(
                    id: id,
                    title: artist,
                    body: randomPrompt(
                        type: "исполнителя",
                        value: artist,
                        count: count,
                        variants: [
                            "{N} пластинок {VALUE}. Дискография сама просится в отдельную полку.",
                            "{VALUE} уже {N} раз на полке. Фан-клуб оформляем официально?",
                            "{N} релизов {VALUE}. Это уже отношения, не просто знакомство."
                        ]
                    ),
                    filterType: .artist,
                    filterValue: artist
                ))
            }
        }

        for (genre, count) in grouped(records.flatMap(\.tags)) where count >= shelfPromptMinCount {
            let id = "genre:\(genre.lowercased())"
            if !ignoredIDs.contains(id), !has(.genre, genre) {
                candidates.append(.init(
                    id: id,
                    title: genre,
                    body: randomPrompt(
                        type: "жанра",
                        value: genre,
                        count: count,
                        variants: [
                            "{N} пластинок жанра «{VALUE}». Жанр уже занял диван — сделать ему отдельную комнату?",
                            "«{VALUE}» набралось на {N} штук. Это уже не настроение, это направление.",
                            "{VALUE} прёт: {N} пластинок. Соберём в одну аккуратную стопку?"
                        ]
                    ),
                    filterType: .genre,
                    filterValue: genre
                ))
            }
        }

        return candidates.randomElement()
    }

    @MainActor
    static func apply(_ s: CollectionSuggestion, records: [VinylRecord], in context: ModelContext) {
        if s.id == "recent" {
            let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
            for r in records where r.addedAt >= monthAgo {
                if !r.tags.contains("недавние") {
                    r.tags.append("недавние")
                }
            }
        }
        let col = SavedCollection(name: s.title, filterType: s.filterType, filterValue: s.filterValue)
        context.insert(col)
        try? context.save()
    }

    private static func grouped(_ values: [String]) -> [(String, Int)] {
        var counts: [String: (value: String, count: Int)] = [:]
        for raw in values {
            let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = clean.lowercased()
            guard !clean.isEmpty, clean != "—", key != "любимое", key != "favorite" else { continue }
            counts[key, default: (clean, 0)].count += 1
        }
        return counts.values
            .map { ($0.value, $0.count) }
            .sorted { $0.1 > $1.1 }
    }

    private static func randomPrompt(type: String, value: String, count: Int, variants: [String]) -> String {
        let template = variants.randomElement() ?? "{N} пластинок \(type) «{VALUE}» — собрать в коллекцию?"
        return template
            .replacingOccurrences(of: "{N}", with: "\(count)")
            .replacingOccurrences(of: "{VALUE}", with: value)
    }
}
