import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserProfile]
    @Query(sort: \VinylRecord.addedAt, order: .reverse) private var records: [VinylRecord]
    @Query(sort: \WishlistEntry.addedAt, order: .reverse) private var wishlist: [WishlistEntry]
    @Query private var collections: [SavedCollection]
    @Query private var userStores: [UserVinylStore]
    @Query(sort: \Achievement.unlockedAt, order: .reverse) private var achievements: [Achievement]

    @State private var name: String = ""
    @State private var handle: String = ""
    @State private var showCSVImporter = false
    @State private var csvDrafts: [CSVImportDraft] = []
    @State private var csvPreview: CSVImportPreview?
    @State private var csvImportProgress = 0
    @State private var csvImportTotal = 0
    @State private var csvImportSummary = ""
    @State private var isImportingCSV = false
    @State private var includePhotosInBackup = true
    @State private var backupDocument = JSONBackupDocument()
    @State private var showBackupExporter = false
    @State private var showBackupImporter = false
    @State private var pendingBackupImport: AppBackup?
    @State private var showRestoreConfirm = false
    @State private var backupStatus = ""
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    @AppStorage("appThemeMode") private var appThemeMode = "system"
    @AppStorage("privateModeEnabled") private var privateModeEnabled = false
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    avatar
                    statsTrio
                    chart
                    achievementsBlock
                    yearlyRecapCard
                    if isImportingCSV || !csvImportSummary.isEmpty {
                        importStatus
                    }
                    if !backupStatus.isEmpty {
                        backupStatusView
                    }
                    settings
                }
                .padding(.vertical, 14)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "profile.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "close")) { dismiss() }.tint(AppTheme.gold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "save")) { save() }.tint(AppTheme.gold)
                }
            }
            .onAppear { syncFromProfile() }
            .fileImporter(isPresented: $showCSVImporter, allowedContentTypes: [.commaSeparatedText, .text]) { result in
                handleCSVImport(result)
            }
            .fileExporter(
                isPresented: $showBackupExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "45-33-backup.json"
            ) { result in
                if case .failure = result {
                    backupStatus = VoiceContent.phrase(.errorGeneric)
                }
            }
            .fileImporter(isPresented: $showBackupImporter, allowedContentTypes: [.json]) { result in
                handleBackupImport(result)
            }
            .alert("Удалить ВСЕ данные?", isPresented: $showClearConfirm) {
                Button("Удалить", role: .destructive) { clearAll() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Это удалит всю коллекцию, вишлист, все теги, профиль и достижения. Действие необратимо.")
            }
            .alert("восстановить копию?", isPresented: $showRestoreConfirm) {
                Button("Заменить данные", role: .destructive) {
                    restorePendingBackup()
                }
                Button("Отмена", role: .cancel) {
                    pendingBackupImport = nil
                }
            } message: {
                Text("Это заменит текущую коллекцию, вишлист, подборки, профиль и пользовательские магазины. Продолжить?")
            }
            .confirmationDialog("импорт коллекции", isPresented: Binding(
                get: { csvPreview != nil },
                set: { if !$0 { csvPreview = nil } }
            ), presenting: csvPreview) { preview in
                Button("Импортировать \(preview.validRows)") {
                    startCSVImport()
                }
                Button("Отмена", role: .cancel) {
                    csvDrafts = []
                    csvPreview = nil
                }
            } message: { preview in
                Text("найдено \(preview.validRows) строк из \(preview.totalRows), импортировать?")
            }
        }
    }

    private var avatar: some View {
        VStack(spacing: 10) {
            Text(profileOrSeed().avatarLetter)
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                .foregroundStyle(AppTheme.bg)
                .frame(width: 70, height: 70)
                .background(AppTheme.gold)
                .clipShape(Circle())

            VStack(spacing: 8) {
                TextField("Имя", text: $name)
                    .textFieldStyle(.roundedBorder)
                TextField("Ник", text: $handle)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
            }
            .padding(.horizontal, 32)
        }
    }

    private var statsTrio: some View {
        HStack(spacing: 8) {
            statBox("\(records.count)", "пластинок")
            statBox(privateModeEnabled ? "€•••" : "€\(Int(totalInvested))", "вложено")
            statBox("\(collections.count + 4)", "коллекций")
        }
        .padding(.horizontal, 20)
    }

    private func statBox(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(AppTheme.gold)
            Text(label.uppercased())
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(AppTheme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(AppTheme.panelLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var chart: some View {
        let stats = decadeBars()
        return VStack(alignment: .leading, spacing: 8) {
            Text("статистика коллекции".uppercased())
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.inkFaint)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(stats.enumerated()), id: \.offset) { idx, val in
                    Rectangle()
                        .fill(idx == 2 ? AppTheme.gold : AppTheme.goldSoft)
                        .frame(height: max(4, CGFloat(val) * 46))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
            .frame(height: 46)

            Text("по десятилетиям")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AppTheme.inkFaint)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(AppTheme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(AppTheme.panelLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private var achievementsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("достижения".uppercased())
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.inkFaint)
            if achievements.isEmpty {
                Text("Пока закрыто. Добавь ещё пластинок — первые значки рядом.")
                    .font(.callout)
                    .foregroundStyle(AppTheme.inkMuted)
            } else {
                ForEach(achievements.prefix(6)) { achievement in
                    HStack {
                        Image(systemName: "seal.fill")
                            .foregroundStyle(AppTheme.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AchievementService.title(for: achievement.kind))
                                .font(.system(.subheadline, design: .serif).weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text(achievement.unlockedAt, format: .dateTime.day().month().year())
                                .font(.caption)
                                .foregroundStyle(AppTheme.inkFaint)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(AppTheme.panelLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private var yearlyRecapCard: some View {
        NavigationLink {
            YearlyRecapView()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Год в виниле")
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text("сводка за период")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.inkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppTheme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(AppTheme.panelLine, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var settings: some View {
        VStack(spacing: 0) {
            settingsRow("О приложении", icon: "chevron.right")
            Rectangle().fill(AppTheme.rowLine).frame(height: 1)
            NavigationLink {
                TagsView(onOpenShelf: {
                    dismiss()
                })
            } label: {
                HStack {
                    Text("Мои теги").foregroundStyle(AppTheme.inkSoft)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(AppTheme.inkFaint)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)
            Rectangle().fill(AppTheme.rowLine).frame(height: 1)
            Toggle("Синхронизация iCloud", isOn: $iCloudSyncEnabled)
                .tint(AppTheme.gold)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
            Text(iCloudSyncEnabled ? "включено · используется приватный CloudKit контейнер" : "выключено · данные остаются локально")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AppTheme.inkFaint)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            Rectangle().fill(AppTheme.rowLine).frame(height: 1)
            Picker("Тема", selection: $appThemeMode) {
                Text("системная").tag("system")
                Text("тёмная").tag("dark")
                Text("светлая").tag("light")
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            Rectangle().fill(AppTheme.rowLine).frame(height: 1)
            Button {
                togglePrivateMode()
            } label: {
                HStack {
                    Text("Приватный режим")
                        .foregroundStyle(AppTheme.inkSoft)
                    Spacer()
                    Text(privateModeEnabled ? "включён" : "выключен")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(privateModeEnabled ? AppTheme.gold : AppTheme.inkFaint)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)
            Rectangle().fill(AppTheme.rowLine).frame(height: 1)
            settingsRow("Импорт коллекции (CSV)", icon: "tray.and.arrow.down", onTap: { showCSVImporter = true })
            Rectangle().fill(AppTheme.rowLine).frame(height: 1)
            settingsRow("Создать резервную копию", icon: "square.and.arrow.up", onTap: exportBackup)
            Rectangle().fill(AppTheme.rowLine).frame(height: 1)
            settingsRow("Восстановить из копии", icon: "arrow.clockwise", onTap: { showBackupImporter = true })
            Rectangle().fill(AppTheme.rowLine).frame(height: 1)
            Toggle("Бэкап с фото", isOn: $includePhotosInBackup)
                .tint(AppTheme.gold)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
            Rectangle().fill(AppTheme.rowLine).frame(height: 1)
            settingsRow("Очистить все данные", icon: "trash", color: AppTheme.red, onTap: { showClearConfirm = true })
        }
        .background(AppTheme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(AppTheme.panelLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private var backupStatusView: some View {
        Text(backupStatus)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(AppTheme.inkMuted)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(AppTheme.panelLine, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
    }

    private func settingsRow(_ title: String, icon: String, color: Color = AppTheme.inkSoft, onTap: (() -> Void)? = nil) -> some View {
        Button {
            onTap?()
        } label: {
            HStack {
                Text(title).foregroundStyle(color)
                Spacer()
                Image(systemName: icon).foregroundStyle(AppTheme.inkFaint)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var importStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isImportingCSV {
                ProgressView(value: Double(csvImportProgress), total: Double(max(1, csvImportTotal)))
                    .tint(AppTheme.gold)
                Text(VoiceContent.phrase(
                    .importCSVProgress,
                    replacements: ["DONE": "\(csvImportProgress)", "TOTAL": "\(csvImportTotal)"]
                ))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AppTheme.inkMuted)
            } else if !csvImportSummary.isEmpty {
                Text(csvImportSummary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.inkMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(AppTheme.panelLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private var totalInvested: Double {
        records.reduce(0) { $0 + $1.price }
    }

    private func decadeBars() -> [Double] {
        var by: [Int: Int] = [50: 0, 60: 0, 70: 0, 80: 0, 90: 0, 0: 0]
        for r in records {
            let d = (r.year / 10) * 10
            let key = d % 100
            if by[key] != nil { by[key]! += 1 }
        }
        let max = by.values.max() ?? 1
        return [50, 60, 70, 80, 90, 0].map { Double(by[$0] ?? 0) / Double(Swift.max(1, max)) }
    }

    private func profileOrSeed() -> UserProfile {
        if let p = profiles.first { return p }
        let p = UserProfile(name: "Marko", handle: "marko.collects", memberSince: 2024, avatarLetter: "M")
        modelContext.insert(p)
        try? modelContext.save()
        return p
    }

    private func syncFromProfile() {
        let p = profileOrSeed()
        if name.isEmpty { name = p.name }
        if handle.isEmpty { handle = p.handle }
    }

    private func save() {
        let p = profileOrSeed()
        if !name.isEmpty { p.name = name }
        if !handle.isEmpty { p.handle = handle.replacingOccurrences(of: "@", with: "") }
        p.avatarLetter = String(p.name.prefix(1)).uppercased()
        try? modelContext.save()
        dismiss()
    }

    private func togglePrivateMode() {
        if privateModeEnabled {
            Task {
                if await PrivacyService.authenticateToDisable() {
                    privateModeEnabled = false
                }
            }
        } else {
            privateModeEnabled = true
        }
    }

    private func clearAll() {
        for r in records { modelContext.delete(r) }
        for w in wishlist { modelContext.delete(w) }
        for c in collections { modelContext.delete(c) }
        for p in profiles { modelContext.delete(p) }
        for s in userStores { modelContext.delete(s) }
        for a in achievements { modelContext.delete(a) }
        try? modelContext.save()
    }

    private func exportBackup() {
        do {
            backupDocument = JSONBackupDocument(data: try BackupService.export(
                records: records,
                wishlist: wishlist,
                collections: collections,
                profile: profiles.first,
                userStores: userStores,
                achievements: achievements,
                includePhotos: includePhotosInBackup
            ))
            showBackupExporter = true
            backupStatus = ""
        } catch {
            backupStatus = VoiceContent.phrase(.errorGeneric)
        }
    }

    private func handleBackupImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        do {
            pendingBackupImport = try BackupService.decode(data: readImportData(from: url))
            showRestoreConfirm = true
        } catch {
            backupStatus = VoiceContent.phrase(.errorGeneric)
        }
    }

    private func restorePendingBackup() {
        guard let backup = pendingBackupImport else { return }
        clearAll()

        backup.records.forEach { snapshot in
            modelContext.insert(VinylRecord(
                id: snapshot.id,
                title: snapshot.title,
                artist: snapshot.artist,
                year: snapshot.year,
                coverColorHex: snapshot.coverColorHex,
                photoData: snapshot.photoDataBase64.flatMap { Data(base64Encoded: $0) },
                vinylColor: VinylColor(rawValue: snapshot.vinylColorRaw) ?? .black,
                grade: RecordGrade(rawValue: snapshot.gradeRaw) ?? .VGPlus,
                price: snapshot.price,
                currency: snapshot.currency,
                pressing: snapshot.pressing,
                label: snapshot.label,
                tags: snapshot.tags,
                isFavorite: snapshot.isFavorite,
                story: snapshot.story,
                purchasedAt: snapshot.purchasedAt,
                purchaseLocation: snapshot.purchaseLocation,
                addedAt: snapshot.addedAt,
                discogsReleaseId: snapshot.discogsReleaseId
            ))
        }

        backup.wishlist.forEach { snapshot in
            modelContext.insert(WishlistEntry(
                id: snapshot.id,
                title: snapshot.title,
                artist: snapshot.artist,
                year: snapshot.year,
                note: snapshot.note,
                addedAt: snapshot.addedAt
            ))
        }

        backup.collections.forEach { snapshot in
            let collection = SavedCollection(
                id: snapshot.id,
                name: snapshot.name,
                filterType: CollectionFilterType(rawValue: snapshot.filterTypeRaw) ?? .tag,
                filterValue: snapshot.filterValue,
                createdAt: snapshot.createdAt
            )
            collection.excludedRecordIDs = snapshot.excludedRecordIDs
            modelContext.insert(collection)
        }

        if let snapshot = backup.profile {
            modelContext.insert(UserProfile(
                id: snapshot.id,
                name: snapshot.name,
                handle: snapshot.handle,
                memberSince: snapshot.memberSince,
                avatarLetter: snapshot.avatarLetter,
                isPremium: snapshot.isPremium,
                defaultShowcaseStyle: snapshot.defaultShowcaseStyle
            ))
        }

        backup.userStores.forEach { snapshot in
            modelContext.insert(UserVinylStore(
                id: snapshot.id,
                syncID: snapshot.syncID,
                name: snapshot.name,
                latitude: snapshot.latitude,
                longitude: snapshot.longitude,
                address: snapshot.address,
                note: snapshot.note,
                sourceRaw: snapshot.sourceRaw,
                syncStatus: VinylStoreSyncStatus(rawValue: snapshot.syncStatusRaw) ?? .localOnly,
                createdByDeviceID: snapshot.createdByDeviceID,
                createdAt: snapshot.createdAt,
                updatedAt: snapshot.updatedAt,
                isDeleted: snapshot.isDeleted
            ))
        }

        backup.achievements.forEach { snapshot in
            modelContext.insert(Achievement(
                id: snapshot.id,
                kind: snapshot.kind,
                unlockedAt: snapshot.unlockedAt,
                recordIdAtUnlock: snapshot.recordIdAtUnlock
            ))
        }

        try? modelContext.save()
        pendingBackupImport = nil
        backupStatus = "копия восстановлена"
    }

    private func handleCSVImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        Task {
            let data = readImportData(from: url)
            let drafts = await Task.detached(priority: .userInitiated) {
                (try? CSVImportService.parseDiscogsExport(data: data)) ?? []
            }.value
            csvDrafts = drafts
            csvPreview = CSVImportPreview(totalRows: drafts.count, validRows: drafts.count)
        }
    }

    private func readImportData(from url: URL) -> Data {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return (try? Data(contentsOf: url)) ?? Data()
    }

    private func startCSVImport() {
        let drafts = csvDrafts
        csvPreview = nil
        csvImportProgress = 0
        csvImportTotal = drafts.count
        csvImportSummary = ""
        isImportingCSV = true

        Task {
            var known = Set(records.map { duplicateKey(artist: $0.artist, title: $0.title, year: $0.year) })
            var imported = 0
            var skipped = 0

            for draft in drafts {
                let key = duplicateKey(artist: draft.artist, title: draft.title, year: draft.released ?? 0)
                if known.contains(key) {
                    skipped += 1
                } else {
                    known.insert(key)
                    modelContext.insert(VinylRecord(
                        title: draft.title,
                        artist: draft.artist,
                        year: draft.released ?? 0,
                        pressing: draft.format.isEmpty ? "—" : draft.format,
                        label: draft.label.isEmpty ? "—" : draft.label,
                        tags: draft.tags,
                        story: draft.story
                    ))
                    imported += 1
                }

                csvImportProgress += 1
                if csvImportProgress.isMultiple(of: 25) {
                    try? modelContext.save()
                    await Task.yield()
                }
            }

            try? modelContext.save()
            isImportingCSV = false
            csvDrafts = []
            csvImportSummary = VoiceContent.phrase(
                .importCSVSummary,
                replacements: ["IMPORTED": "\(imported)", "SKIPPED": "\(skipped)"]
            )
        }
    }

    private func duplicateKey(artist: String, title: String, year: Int) -> String {
        "\(artist)|\(title)|\(year)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
