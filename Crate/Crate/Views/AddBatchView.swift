import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import UIKit

struct AddBatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VinylRecord.addedAt, order: .reverse) private var shelfRecords: [VinylRecord]
    @Query(sort: \Achievement.unlockedAt, order: .reverse) private var achievements: [Achievement]

    @State private var draft: [BatchItem] = []
    @State private var showScanner = false
    @State private var scannerError: String?
    @State private var isLoading = false
    @State private var lastError: String?
    @State private var showManualAdd = false
    @State private var saveStatus: String?
    @State private var pendingAchievements: [Achievement] = []
    @State private var achievementIndex = 0
    @State private var showAchievementSheet = false

    struct BatchItem: Identifiable, Hashable {
        let id = UUID()
        var release: DiscogsSearchResult?
        var manual: ManualDraft?
        var flag: Flag?

        enum Flag: Hashable { case duplicate, multipleEditions }

        struct ManualDraft: Hashable {
            let title: String
            let artist: String
            let year: Int
            let label: String
            let pressing: String
            let tags: [String]
            let story: String
            let photoData: Data?
        }

        init(release: DiscogsSearchResult, flag: Flag? = nil) {
            self.release = release
            self.manual = nil
            self.flag = flag
        }

        init(manual: ManualDraft) {
            self.release = nil
            self.manual = manual
            self.flag = nil
        }

        var title: String {
            manual?.title ?? release?.parsedAlbum ?? "Без названия"
        }

        var artist: String {
            manual?.artist ?? release?.parsedArtist ?? "Unknown"
        }

        var subtitle: String {
            if let manual {
                return "вручную · \(manual.year)"
            }
            if let release {
                return "\(release.parsedArtist)\(release.yearInt.map { " · \($0)" } ?? "")"
            }
            return "—"
        }

        var isManual: Bool { manual != nil }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scannerHeader

                if let lastError {
                    Text(lastError)
                        .font(.callout)
                        .foregroundStyle(AppTheme.red)
                        .padding()
                }

                if let saveStatus {
                    Text(saveStatus)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.inkFaint)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                List {
                    ForEach(draft) { item in
                        BatchRow(item: item) { remove(item) }
                            .listRowBackground(AppTheme.bg)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppTheme.bg)

                if !draft.isEmpty {
                    Button {
                        Task { await commit() }
                    } label: {
                        Text("сохранить \(draft.count)".uppercased())
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.gold)
                    .padding(20)
                }
            }
            .background(AppTheme.bg)
            .navigationTitle("Сканировать стопку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.tint(AppTheme.gold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showManualAdd = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .tint(AppTheme.gold)
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerSheet { code in
                    showScanner = false
                    Task { await handleCode(code) }
                } onError: { msg in
                    scannerError = msg
                    showScanner = false
                }
            }
            .sheet(isPresented: $showManualAdd) {
                BatchManualRecordView { manual in
                    draft.append(BatchItem(manual: manual))
                }
            }
            .alert("Сканер", isPresented: Binding(get: { scannerError != nil }, set: { if !$0 { scannerError = nil } })) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(scannerError ?? "")
            }
            .sheet(isPresented: $showAchievementSheet) {
                AchievementUnlockedSheet(
                    achievements: pendingAchievements,
                    records: shelfRecords,
                    index: $achievementIndex,
                    onDismissAll: {
                        pendingAchievements = []
                        achievementIndex = 0
                        showAchievementSheet = false
                        dismiss()
                    }
                )
            }
        }
    }

    private var scannerHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button { showScanner = true } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.title)
                        Text(isLoading ? "Ищу..." : "Скан")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AppTheme.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(AppTheme.bgDeep)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.panelLine, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(AppTheme.gold)
                }

                Button { showManualAdd = true } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                            .font(.title)
                        Text("Вручную")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AppTheme.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(AppTheme.bgDeep)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.panelLine, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(AppTheme.gold)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Text("В стопке: \(draft.count)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.inkFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
        }
    }

    @MainActor
    private func handleCode(_ code: String) async {
        lastError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let results = try await DiscogsService.shared.searchByBarcode(code)
            guard let first = results.first else {
                lastError = "Не нашли. Проверь имя артиста — Discogs строгий к написанию."
                return
            }
            let onShelf = recordExists(first)
            let flag: BatchItem.Flag? = onShelf ? .duplicate : (results.count > 1 ? .multipleEditions : nil)
            draft.append(BatchItem(release: first, flag: flag))
        } catch {
            lastError = VoiceContent.phrase(.errorNetworkDiscogs)
        }
    }

    private func recordExists(_ r: DiscogsSearchResult) -> Bool {
        let descriptor = FetchDescriptor<VinylRecord>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.contains { $0.title.lowercased() == r.parsedAlbum.lowercased() && $0.artist.lowercased() == r.parsedArtist.lowercased() }
    }

    private func remove(_ item: BatchItem) {
        draft.removeAll { $0.id == item.id }
    }

    @MainActor
    private func commit() async {
        isLoading = true
        saveStatus = "Сохранение…"
        defer { isLoading = false }

        var lastInserted: VinylRecord?
        for item in draft where item.flag != .duplicate {
            if let manual = item.manual {
                let record = VinylRecord(
                    title: manual.title,
                    artist: manual.artist,
                    year: manual.year,
                    coverColorHex: "#5a4a7a",
                    photoData: manual.photoData,
                    pressing: manual.pressing.isEmpty ? "—" : manual.pressing,
                    label: manual.label.isEmpty ? "—" : manual.label,
                    tags: manual.tags,
                    story: manual.story
                )
                modelContext.insert(record)
                lastInserted = record
            } else if let releaseResult = item.release {
                let record = DiscogsService.shared.mapSearchResult(releaseResult)
                modelContext.insert(record)
                lastInserted = record
                downloadCoverInBackground(for: record, urlString: releaseResult.cover_image ?? releaseResult.thumb)
            }
        }
        try? modelContext.save()
        let unlocked = AchievementService.evaluate(
            records: shelfRecords,
            existing: achievements,
            context: modelContext,
            triggerRecord: lastInserted
        )
        try? modelContext.save()
        WidgetSnapshotService.update(records: shelfRecords)
        if !unlocked.isEmpty {
            pendingAchievements = unlocked
            achievementIndex = 0
            showAchievementSheet = true
            return
        }
        dismiss()
    }

    @MainActor
    private func downloadCoverInBackground(for record: VinylRecord, urlString: String?) {
        Task {
            guard let data = try? await DiscogsService.shared.fetchImageData(urlString: urlString) else { return }
            record.photoData = ImageDataTools.compressedJPEG(from: data)
            try? modelContext.save()
            WidgetSnapshotService.update(records: shelfRecords)
        }
    }
}

struct BatchRow: View {
    let item: AddBatchView.BatchItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let data = item.manual?.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let thumb = item.release?.thumb {
                    AsyncImage(url: URL(string: thumb)) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: Rectangle().fill(AppTheme.panelLine)
                        }
                    }
                } else {
                    Rectangle().fill(AppTheme.panelLine)
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(AppTheme.inkFaint)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(.callout, design: .serif).weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkFaint)
                if item.isManual {
                    Text("ручной ввод")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.green)
                }
                if item.flag == .multipleEditions {
                    Text(VoiceContent.phrase(.warnAmbiguousBarcode, replacements: ["N": "несколько"]))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.gold)
                }
                if item.flag == .duplicate {
                    Text(VoiceContent.phrase(.warnDuplicate))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.red)
                }
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .foregroundStyle(AppTheme.inkFaint)
            }
        }
        .padding(.vertical, 4)
    }
}

struct BatchManualRecordView: View {
    let onAdd: (AddBatchView.BatchItem.ManualDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var artist = ""
    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var label = ""
    @State private var pressing = ""
    @State private var tags = ""
    @State private var story = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showCamera = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Фото") {
                    HStack(spacing: 14) {
                        RecordCover(colorHex: "#5a4a7a", photoData: photoData)
                            .frame(width: 76, height: 76)
                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label("Галерея", systemImage: "photo")
                            }
                            Button {
                                showCamera = true
                            } label: {
                                Label("Камера", systemImage: "camera")
                            }
                        }
                    }
                }

                Section("Основное") {
                    TextField("Альбом", text: $title)
                    TextField("Артист", text: $artist)
                    Stepper("Год: \(year)", value: $year, in: 1900...2100)
                    TextField("Лейбл", text: $label)
                    TextField("Прессинг", text: $pressing)
                }

                Section("Дополнительно") {
                    TextField("Теги через запятую", text: $tags)
                    TextField("История / заметка", text: $story, axis: .vertical)
                }

                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(AppTheme.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.bg)
            .navigationTitle("В стопку вручную")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.tint(AppTheme.gold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Добавить") { addToBatch() }.tint(AppTheme.gold)
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
            .sheet(isPresented: $showCamera) {
                CameraView { image in
                    photoData = ImageDataTools.compressedJPEG(from: image)
                    showCamera = false
                }
            }
        }
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        photoData = ImageDataTools.compressedJPEG(from: data)
    }

    private func addToBatch() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanArtist.isEmpty else {
            errorText = "Заполни альбом и артиста."
            return
        }

        let manual = AddBatchView.BatchItem.ManualDraft(
            title: cleanTitle,
            artist: cleanArtist,
            year: year,
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            pressing: pressing.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            story: story.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: photoData
        )
        onAdd(manual)
        dismiss()
    }
}
