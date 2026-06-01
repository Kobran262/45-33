import AppIntents
import Foundation
import SwiftData

struct AddVinylRecordIntent: AppIntent {
    static var title: LocalizedStringResource = "Добавить пластинку"
    static var description = IntentDescription("Ищет релиз в Discogs и добавляет первую найденную виниловую пластинку на полку.")
    static var openAppWhenRun = false

    @Parameter(title: "Артист")
    var artist: String

    @Parameter(title: "Название")
    var title: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let results = try await DiscogsService.shared.searchReleases(query: "\(artist) \(title)")
        guard let first = results.first else {
            return .result(dialog: "Не нашли релиз в Discogs. Попробуй уточнить название.")
        }

        let container = try IntentModelContainerFactory.make()
        let context = ModelContext(container)
        let record: VinylRecord
        if let release = try? await DiscogsService.shared.fetchRelease(id: first.id) {
            record = DiscogsService.shared.mapToRecord(release)
        } else {
            record = DiscogsService.shared.mapSearchResult(first)
        }
        context.insert(record)
        try context.save()
        return .result(dialog: "Добавил: \(record.artist) — \(record.title).")
    }
}

struct OpenWishlistIntent: AppIntent {
    static var title: LocalizedStringResource = "Открыть вишлист"
    static var description = IntentDescription("Открывает вкладку вишлиста в 45/33.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(true, forKey: "pendingOpenWishlist")
        return .result(dialog: "Открываю вишлист.")
    }
}

struct LastAddedRecordIntent: AppIntent {
    static var title: LocalizedStringResource = "Последняя пластинка"
    static var description = IntentDescription("Показывает последнюю добавленную пластинку.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try IntentModelContainerFactory.make()
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<VinylRecord>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let record = try context.fetch(descriptor).first else {
            return .result(dialog: "Полка пока пуста.")
        }
        return .result(dialog: "Последняя на полке: \(record.artist) — \(record.title).")
    }
}

struct CrateShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddVinylRecordIntent(),
            phrases: [
                "Добавь пластинку в \(.applicationName)",
                "Добавить винил в \(.applicationName)"
            ],
            shortTitle: "Добавить пластинку",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: OpenWishlistIntent(),
            phrases: [
                "Открой вишлист в \(.applicationName)",
                "Покажи вишлист в \(.applicationName)"
            ],
            shortTitle: "Открыть вишлист",
            systemImageName: "heart"
        )
        AppShortcut(
            intent: LastAddedRecordIntent(),
            phrases: [
                "Что последнее в \(.applicationName)",
                "Последняя пластинка в \(.applicationName)"
            ],
            shortTitle: "Последняя пластинка",
            systemImageName: "tray.full"
        )
    }
}

enum IntentModelContainerFactory {
    static func make() throws -> ModelContainer {
        let schema = Schema([
            VinylRecord.self,
            WishlistEntry.self,
            SavedCollection.self,
            UserProfile.self,
            UserVinylStore.self,
            Achievement.self,
        ])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        )
    }
}
