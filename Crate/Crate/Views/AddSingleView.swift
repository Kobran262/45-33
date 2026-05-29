import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct AddSingleView: View {
    enum Mode: Hashable { case shelf, wishlist }
    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var results: [DiscogsSearchResult] = []
    @State private var showScanner = false
    @State private var scannerError: String?
    @State private var previewResult: DiscogsSearchResult?
    @State private var showManualAdd = false

    init(mode: Mode = .shelf) { self.mode = mode }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    searchField

                    HStack(spacing: 10) {
                        Button {
                            showScanner = true
                        } label: {
                            Label("Скан", systemImage: "barcode.viewfinder")
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            showManualAdd = true
                        } label: {
                            Label("Вручную", systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .buttonStyle(.bordered)
                    .tint(AppTheme.gold)
                    .padding(.horizontal, 20)

                    if let errorText {
                        Text(errorText)
                            .font(.callout)
                            .foregroundStyle(AppTheme.red)
                            .padding(.horizontal, 20)
                    }

                    if isLoading {
                        VStack(spacing: 8) {
                            ProgressView().tint(AppTheme.gold)
                            Text(VoiceContent.phrase(.loadingDiscogs))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(AppTheme.inkFaint)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                    }

                    if !results.isEmpty {
                        Text("найдено в Discogs · нажми на релиз для предпросмотра")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(AppTheme.inkFaint)
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                    }

                    LazyVStack(spacing: 10) {
                        ForEach(results) { result in
                            DiscogsResultCard(result: result) {
                                previewResult = result
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    if results.isEmpty && !query.isEmpty && !isLoading {
                        Text(VoiceContent.phrase(.emptySearchResults))
                            .font(.footnote)
                            .foregroundStyle(AppTheme.inkFaint)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 16)
            }
            .background(AppTheme.bg)
            .navigationTitle(mode == .shelf ? "Новая пластинка" : "В вишлист")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.tint(AppTheme.gold)
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerSheet { code in
                    showScanner = false
                    query = code
                    Task { await runSearch(barcode: code) }
                } onError: { msg in
                    scannerError = msg
                    showScanner = false
                }
            }
            .sheet(item: $previewResult) { result in
                DiscogsReleasePreviewView(result: result, mode: mode) { release, shouldDownloadCover in
                    await commit(release: release, shouldDownloadCover: shouldDownloadCover)
                }
            }
            .sheet(isPresented: $showManualAdd) {
                ManualRecordAddView(mode: mode) {
                    dismiss()
                }
            }
            .alert("Сканер", isPresented: Binding(get: { scannerError != nil }, set: { if !$0 { scannerError = nil } })) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(scannerError ?? "")
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.inkFaint)
            TextField("артист или альбом...", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .onSubmit { Task { await runSearch() } }
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(AppTheme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(AppTheme.panelLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .padding(.horizontal, 20)
    }

    @MainActor
    private func runSearch(barcode: String? = nil) async {
        errorText = nil
        isLoading = true
        results = []
        defer { isLoading = false }

        do {
            if let barcode {
                results = try await DiscogsService.shared.searchByBarcode(barcode)
                if results.isEmpty {
                    errorText = VoiceContent.phrase(.emptySearchResults)
                }
            } else {
                let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !q.isEmpty else { return }
                results = try await DiscogsService.shared.searchReleases(query: q)
            }
        } catch {
            errorText = friendlyError(error)
        }
    }

    @MainActor
    private func commit(release: DiscogsRelease, shouldDownloadCover: Bool) async {
        do {
            switch mode {
            case .shelf:
                let record = DiscogsService.shared.mapToRecord(release)
                if shouldDownloadCover, let data = try await DiscogsService.shared.fetchImageData(urlString: release.primaryImageURL) {
                    record.photoData = ImageDataTools.compressedJPEG(from: data)
                }
                modelContext.insert(record)
            case .wishlist:
                let entry = WishlistEntry(
                    title: release.title,
                    artist: release.primaryArtist,
                    year: release.year
                )
                modelContext.insert(entry)
            }
            try modelContext.save()
            dismiss()
        } catch {
            errorText = friendlyError(error)
        }
    }

    @MainActor
    private func friendlyError(_ error: Error) -> String {
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            return "Похоже, интернет пропал. Проверь связь."
        }
        if error is DiscogsError {
            return VoiceContent.phrase(.errorNetworkDiscogs)
        }
        return (error as? LocalizedError)?.errorDescription ?? VoiceContent.phrase(.errorGeneric)
    }
}

struct DiscogsResultCard: View {
    let result: DiscogsSearchResult
    let onPreview: () -> Void

    var body: some View {
        Button(action: onPreview) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: result.thumb ?? result.cover_image ?? "")) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Rectangle().fill(AppTheme.panelLine)
                    }
                }
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.parsedAlbum)
                        .font(.system(.callout, design: .serif).weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                    Text("\(result.parsedArtist)\(result.yearInt.map { " · \($0)" } ?? "")")
                        .font(.caption)
                        .foregroundStyle(AppTheme.inkFaint)
                    if let label = result.label?.first {
                        Text(label)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(AppTheme.inkFaint)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "info.circle")
                    .foregroundStyle(AppTheme.gold)
                    .font(.title3)
            }
            .padding(12)
            .background(AppTheme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.panelLine, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct DiscogsReleasePreviewView: View {
    let result: DiscogsSearchResult
    let mode: AddSingleView.Mode
    let onCommit: (DiscogsRelease, Bool) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var release: DiscogsRelease?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var downloadCover = true
    @State private var factText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    cover

                    VStack(spacing: 6) {
                        Text(release?.title.components(separatedBy: " - ").last ?? result.parsedAlbum)
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .multilineTextAlignment(.center)
                        Text(release?.primaryArtist ?? result.parsedArtist)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.inkMuted)
                    }
                    .padding(.horizontal, 20)

                    if let errorText {
                        Text(errorText)
                            .font(.callout)
                            .foregroundStyle(AppTheme.red)
                            .padding(.horizontal, 20)
                    }

                    if isLoading {
                        ProgressView().tint(AppTheme.gold)
                    } else {
                        details
                        if let factText {
                            factBlock(factText)
                        }
                        coverOption
                        actionButtons
                    }
                }
                .padding(.vertical, 18)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("Предпросмотр")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Назад") { dismiss() }.tint(AppTheme.gold)
                }
            }
            .task { await loadRelease() }
        }
    }

    private var cover: some View {
        AsyncImage(url: URL(string: release?.primaryImageURL ?? result.cover_image ?? result.thumb ?? "")) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    Rectangle().fill(AppTheme.panelLine)
                    Image(systemName: "record.circle")
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.inkFaint)
                }
            }
        }
        .frame(width: 210, height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
    }

    private var details: some View {
        VStack(spacing: 0) {
            previewRow("Год", value: release?.year.map(String.init) ?? result.year ?? "—")
            divider
            previewRow("Страна", value: release?.country ?? result.country ?? "—")
            divider
            previewRow("Лейбл", value: release?.primaryLabel ?? result.label?.first ?? "—")
            divider
            previewRow("Формат", value: release?.formatDescription ?? result.format?.prefix(3).joined(separator: " · ") ?? "—")
            divider
            previewRow("Barcode", value: release?.barcodeValue ?? result.barcode?.first ?? "—")
        }
        .padding(.horizontal, 14)
        .background(AppTheme.panel)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.panelLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private var coverOption: some View {
        Toggle(isOn: $downloadCover) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Скачать обложку Discogs")
                    .foregroundStyle(AppTheme.ink)
                Text("Фото сохранится локально в карточке пластинки")
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkFaint)
            }
        }
        .toggleStyle(.switch)
        .tint(AppTheme.gold)
        .padding(14)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .disabled(mode == .wishlist)
    }

    private func factBlock(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("факт".uppercased())
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.inkFaint)
            Text(text)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(AppTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.panel)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.panelLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                guard let release else { return }
                isSaving = true
                Task {
                    await onCommit(release, mode == .shelf && downloadCover)
                    isSaving = false
                    dismiss()
                }
            } label: {
                if isSaving {
                    ProgressView().tint(AppTheme.bg)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(mode == .shelf ? "добавить на полку" : "добавить в вишлист")
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.gold)
            .disabled(release == nil || isSaving)

            if mode == .shelf {
                Text("После добавления фото можно заменить вручную в карточке пластинки.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkFaint)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
    }

    private var divider: some View {
        Rectangle().fill(AppTheme.rowLine).frame(height: 1)
    }

    private func previewRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.inkFaint)
            Spacer(minLength: 16)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 9)
    }

    @MainActor
    private func loadRelease() async {
        guard release == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            release = try await DiscogsService.shared.fetchRelease(id: result.id)
            if let release, Int.random(in: 0..<10) < 6 {
                factText = VoiceContent.fact(for: release, fallbackResult: result)
            }
        } catch {
            errorText = VoiceContent.phrase(.errorNetworkDiscogs)
        }
    }
}

struct ManualRecordAddView: View {
    let mode: AddSingleView.Mode
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
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
                            .frame(width: 86, height: 86)
                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label("Выбрать из галереи", systemImage: "photo")
                            }
                            Button {
                                showCamera = true
                            } label: {
                                Label("Снять камерой", systemImage: "camera")
                            }
                            if photoData != nil {
                                Button(role: .destructive) {
                                    photoData = nil
                                } label: {
                                    Label("Убрать фото", systemImage: "trash")
                                }
                            }
                        }
                        .font(.callout)
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
                    TextEditor(text: $story)
                        .frame(minHeight: 90)
                }

                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(AppTheme.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.bg)
            .navigationTitle(mode == .shelf ? "Вручную" : "В вишлист")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.tint(AppTheme.gold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") { save() }.tint(AppTheme.gold)
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

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanArtist.isEmpty else {
            errorText = "Заполни альбом и артиста."
            return
        }

        switch mode {
        case .shelf:
            let record = VinylRecord(
                title: cleanTitle,
                artist: cleanArtist,
                year: year,
                coverColorHex: "#5a4a7a",
                photoData: photoData,
                pressing: pressing.isEmpty ? "—" : pressing,
                label: label.isEmpty ? "—" : label,
                tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
                story: story
            )
            modelContext.insert(record)
        case .wishlist:
            modelContext.insert(WishlistEntry(title: cleanTitle, artist: cleanArtist, year: year))
        }

        try? modelContext.save()
        dismiss()
        onSaved()
    }
}

/// Презентация сканера + permission flow
struct BarcodeScannerSheet: View {
    let onCode: (String) -> Void
    let onError: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                if permissionDenied {
                    VStack(spacing: 14) {
                        Image(systemName: "camera.metering.unknown")
                            .font(.largeTitle)
                            .foregroundStyle(AppTheme.inkFaint)
                        Text("Доступ к камере выключен")
                            .font(.system(.title3, design: .serif))
                        Text("Включи в Настройках -> 45/33 -> Камера.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    BarcodeScannerView(onCode: onCode, onError: onError)
                        .ignoresSafeArea()
                }
            }
            .background(AppTheme.bg)
            .navigationTitle("Штрихкод")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }.tint(AppTheme.gold)
                }
            }
            .task { await ensurePermission() }
        }
    }

    @MainActor
    private func ensurePermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: permissionDenied = false
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionDenied = !granted
        case .denied, .restricted: permissionDenied = true
        @unknown default: permissionDenied = true
        }
    }
}
