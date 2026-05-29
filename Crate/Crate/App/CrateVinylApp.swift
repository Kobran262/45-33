import SwiftUI
import SwiftData

@main
struct CrateVinylApp: App {
    private let container: ModelContainer

    init() {
        Self.ensureApplicationSupportExists()

        let schema = Schema([
            VinylRecord.self,
            WishlistEntry.self,
            SavedCollection.self,
            UserProfile.self,
            UserVinylStore.self,
        ])

        do {
            container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            )
        } catch {
            print("SwiftData persistent store failed, fallback to in-memory: \(error)")
            container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    /// Создаёт `~/Library/Application Support/` если её нет, чтобы SwiftData
    /// не сыпал многословный recovery-лог при первом запуске.
    private static func ensureApplicationSupportExists() {
        let fm = FileManager.default
        guard let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
