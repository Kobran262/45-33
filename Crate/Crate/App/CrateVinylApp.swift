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
            Achievement.self,
        ])

        let iCloudSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

        if iCloudSyncEnabled {
            do {
                container = try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: false,
                        cloudKitDatabase: .private("iCloud.crate.45-33")
                    )
                )
                return
            } catch {
                print("SwiftData CloudKit store failed, fallback to local store: \(error)")
            }
        }

        do {
            container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            )
        } catch {
            print("SwiftData local store failed, fallback to in-memory: \(error)")
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
