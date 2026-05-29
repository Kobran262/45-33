import SwiftUI
import SwiftData

struct ShowcaseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VinylRecord.addedAt, order: .reverse) private var records: [VinylRecord]
    @Query(sort: \SavedCollection.createdAt, order: .reverse) private var collections: [SavedCollection]

    @State private var showCreateCollection = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if let latest = records.first {
                    NavigationLink {
                        ShowcaseRecordView(record: latest)
                    } label: {
                        ShowcasePickCard(
                            title: "Карточка пластинки",
                            subtitle: "один релиз · ручная настройка",
                            preview: AnyView(
                                RecordCover(colorHex: latest.coverColorHex, photoData: latest.photoData)
                                    .frame(width: 56, height: 56)
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }

                if !records.isEmpty {
                    NavigationLink {
                        ShowcaseCollectionView(collection: nil)
                    } label: {
                        ShowcasePickCard(
                            title: "Вся полка",
                            subtitle: "карточка всей коллекции",
                            preview: AnyView(MiniGrid(records: Array(records.prefix(4))))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }

                collectionsBlock

                if records.isEmpty {
                    Text("Сначала добавь пластинку на полку — тогда появится что показать.")
                        .font(.callout)
                        .foregroundStyle(AppTheme.inkFaint)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 40)
                }

                Spacer(minLength: 24)
            }
            .padding(.vertical, 16)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCreateCollection) {
            CreateCollectionView(records: records)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ВИТРИНА")
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(AppTheme.inkFaint)
                    Text("Поделиться")
                        .font(.system(.title, design: .serif).weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer()
                Button {
                    showCreateCollection = true
                } label: {
                    Label("коллекция", systemImage: "folder.badge.plus")
                        .font(.system(size: 11, design: .monospaced))
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.gold)
                .disabled(records.isEmpty)
            }

            Text("Готовые PNG-карточки для сторис и чатов. Перед отправкой можно настроить текст, ник и стиль.")
                .italic()
                .font(.system(.callout, design: .serif))
                .foregroundStyle(AppTheme.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .feltPanel()
        .padding(.horizontal, 16)
    }

    private var collectionsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("коллекции".uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.inkFaint)
                Spacer()
                Button {
                    showCreateCollection = true
                } label: {
                    Text("＋ создать")
                        .font(.system(size: 10, design: .monospaced))
                }
                .tint(AppTheme.gold)
                .disabled(records.isEmpty)
            }
            .padding(.horizontal, 20)

            if collections.isEmpty {
                Text("Пока нет сохранённых коллекций. Создай фильтр по тегу, артисту, десятилетию или любимым.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkFaint)
                    .padding(.horizontal, 20)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(collections) { collection in
                        NavigationLink {
                            ShowcaseCollectionView(collection: collection)
                        } label: {
                            ShowcasePickCard(
                                title: collection.name,
                                subtitle: collectionDescription(collection),
                                preview: AnyView(MiniGrid(records: Array(records.filter { collection.matches($0) }.prefix(4))))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func collectionDescription(_ collection: SavedCollection) -> String {
        let count = records.filter { collection.matches($0) }.count
        return "\(count) пластинок · \(collection.filterTypeRaw): \(collection.filterValue)"
    }
}

struct ShowcasePickCard: View {
    let title: String
    let subtitle: String
    let preview: AnyView

    var body: some View {
        HStack(spacing: 14) {
            preview
                .frame(width: 64, height: 64)
                .background(AppTheme.bgDeep)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.callout, design: .serif).weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkFaint)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.inkFaint)
        }
        .padding(14)
        .background(AppTheme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.panelLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct MiniGrid: View {
    let records: [VinylRecord]

    var body: some View {
        AdaptiveCollectionCoverGrid(records: records, spacing: 3, maxColumns: 2)
            .padding(6)
    }
}

struct ShowcaseCollectionView: View {
    let collection: SavedCollection?

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VinylRecord.addedAt, order: .reverse) private var allRecords: [VinylRecord]
    @Query private var profiles: [UserProfile]

    @State private var showSharePreview = false

    private var records: [VinylRecord] {
        if let collection {
            return allRecords.filter { collection.matches($0) }
        }
        return allRecords
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                collectionHeader

                Text("пластинки".uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                AdaptiveRecordGrid(records: records)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 12)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle(collection?.name ?? "Вся полка")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Закрыть") { dismiss() }.tint(AppTheme.gold)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSharePreview = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .tint(AppTheme.gold)
            }
        }
        .navigationDestination(isPresented: $showSharePreview) {
            ShowcaseCollectionShareView(
                records: records,
                title: collection?.name ?? "Вся полка",
                handle: profileHandle,
                captionTag: collection?.filterValue
            )
        }
    }

    private var collectionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("коллекция".uppercased())
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(AppTheme.inkFaint)
                    Text(collection?.name ?? "Вся полка")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer()
                Text("\(records.count)")
                    .font(.system(.title, design: .serif).weight(.semibold))
                    .foregroundStyle(AppTheme.gold)
            }

            HStack(spacing: 8) {
                GoldChip(text: yearsRange, active: false)
                GoldChip(text: collection?.filterTypeRaw ?? "all", active: false)
                if let collection {
                    GoldChip(text: collection.filterValue, active: false)
                }
            }
        }
        .feltPanel()
        .padding(.horizontal, 16)
    }

    private var yearsRange: String {
        let validYears = records.map(\.year).filter { $0 > 0 }
        guard let min = validYears.min(), let max = validYears.max() else { return "—" }
        return min == max ? "\(min)" : "\(min)–\(max)"
    }

    private var profileHandle: String {
        let raw = profiles.first?.handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "collector"
        return (raw?.isEmpty == false ? raw! : fallback).replacingOccurrences(of: "@", with: "")
    }
}

struct ShowcaseCollectionShareView: View {
    let records: [VinylRecord]
    let title: String
    let handle: String
    let captionTag: String?

    @State private var sharePayload: SharePayload?
    @State private var showSettings = false
    @State private var settings: ShowcaseCardSettings

    init(records: [VinylRecord], title: String, handle: String, captionTag: String?) {
        self.records = records
        self.title = title
        self.handle = handle
        self.captionTag = captionTag
        self._settings = State(initialValue: ShowcaseCardSettings(title: title, handle: handle))
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("предпросмотр png-карточки".uppercased())
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.inkFaint)
                .padding(.top, 8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ShowcaseStyleStrip(settings: $settings)
                    collectionShareCard
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }

            HStack(spacing: 10) {
                Button {
                    showSettings = true
                } label: {
                    Label("настроить", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.inkMuted)

                Button {
                    shareCollectionPNG()
                } label: {
                    Label("поделиться", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.gold)
            }
            .font(.system(size: 12, design: .monospaced))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("Витрина")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
        .sheet(isPresented: $showSettings) {
            ShowcaseCardSettingsView(settings: $settings) {
                VoiceContent.phrase(
                    .vitrinaCaptionCollection,
                    replacements: [
                        "YEARS": collectionYearsCaption,
                        "TAG": captionTag ?? settings.title,
                        "N": "\(records.count)"
                    ]
                )
            }
        }
    }

    @ViewBuilder
    private var collectionShareCard: some View {
        CollectionShareCard(
            records: records,
            title: normalizedSettings().title,
            handle: normalizedSettings().handle,
            subtitle: normalizedSettings().subtitle,
            showStats: normalizedSettings().showStats,
            cardStyle: normalizedSettings().cardStyle,
            metric: normalizedSettings().collectionMetric
        )
    }

    private var collectionYearsCaption: String {
        let validYears = records.map(\.year).filter { $0 > 0 }
        guard let min = validYears.min(), let max = validYears.max() else { return "несколько" }
        return "\(max - min + 1)"
    }

    private func normalizedSettings() -> ShowcaseCardSettings {
        var copy = settings
        if copy.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.title = title
        }
        if copy.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.handle = handle
        }
        copy.handle = copy.handle.replacingOccurrences(of: "@", with: "")
        return copy
    }

    @MainActor
    private func shareCollectionPNG() {
        let exportSettings = normalizedSettings()
        let url = SharePNGExporter.temporaryPNGURL(
            filename: exportSettings.title,
            width: 340
        ) {
            CollectionShareCard(
                records: records,
                title: exportSettings.title,
                handle: exportSettings.handle,
                subtitle: exportSettings.subtitle,
                showStats: exportSettings.showStats,
                cardStyle: exportSettings.cardStyle,
                metric: exportSettings.collectionMetric
            )
        }

        if let url {
            sharePayload = SharePayload(items: [url])
        }
    }
}

struct CollectionShareCard: View {
    let records: [VinylRecord]
    let title: String
    let handle: String
    let subtitle: String
    let showStats: Bool
    let cardStyle: ShowcaseCardSettings.CardStyle
    let metric: ShowcaseCardSettings.CollectionMetric

    var body: some View {
        VStack(spacing: cardStyle == .magazine ? 12 : 8) {
            Text("КОЛЛЕКЦИЯ ВИНИЛА")
                .font(.system(size: 8, design: .monospaced))
                .tracking(2)
                .foregroundStyle(palette.muted)
            Text(title)
                .font(.system(cardStyle == .magazine ? .title2 : .title3, design: cardStyle == .minimalMono ? .default : .serif).weight(cardStyle == .minimalMono ? .bold : .semibold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }

            AdaptiveCollectionCoverGrid(records: records, spacing: 6, maxColumns: 6)
            .padding(.horizontal, 18)
            .padding(.top, 6)

            if showStats {
                HStack(spacing: 18) {
                    statTile("ПЛАСТИНОК", "\(records.count)")
                    statTile("ГОДЫ", yearsRange)
                    statTile(metric.label.uppercased(), metricValue)
                }
                .padding(.top, 8)
                .padding(.horizontal, 18)
            }

            HStack {
                Text("@\(handle.replacingOccurrences(of: "@", with: ""))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(palette.muted)
                Spacer()
                HStack(spacing: 5) {
                    SpeedMark45_33(showText: false)
                        .frame(width: 16, height: 16)
                    Text("45/33")
                        .font(.system(size: 11, design: .serif))
                }
                .foregroundStyle(palette.accent)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .overlay(
                Rectangle().fill(palette.border).frame(height: 1).padding(.horizontal, 18),
                alignment: .top
            )
        }
        .padding(.vertical, 18)
        .background(palette.bg)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerCard)
                .stroke(palette.border, lineWidth: cardStyle == .magazine ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerCard))
    }

    private var yearsRange: String {
        let validYears = records.map(\.year).filter { $0 > 0 }
        guard let min = validYears.min(), let max = validYears.max() else { return "—" }
        return min == max ? "\(min)" : "\(min)–\(max)"
    }

    private var metricValue: String {
        switch metric {
        case .topGenre:
            return mostCommon(records.flatMap(\.tags)) ?? "—"
        case .topArtist:
            return mostCommon(records.map(\.artist)) ?? "—"
        case .favorites:
            return "\(records.filter(\.isFavorite).count)"
        case .totalValue:
            let total = records.reduce(0) { $0 + $1.price }
            return total > 0 ? "€\(Int(total))" : "—"
        }
    }

    private func mostCommon(_ values: [String]) -> String? {
        var counts: [String: Int] = [:]
        values.forEach {
            let clean = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty && clean != "—" {
                counts[clean, default: 0] += 1
            }
        }
        return counts.max { $0.value < $1.value }?.key ?? "—"
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.callout, design: .serif).weight(.semibold))
                .foregroundStyle(palette.accent)
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var palette: ShowcasePalette {
        ShowcasePalette(style: cardStyle)
    }
}

struct AdaptiveCollectionCoverGrid: View {
    let records: [VinylRecord]
    let spacing: CGFloat
    let maxColumns: Int

    private var columnsCount: Int {
        guard !records.isEmpty else { return 1 }
        let count = records.count
        let proposed = Int(ceil(sqrt(Double(count))))
        return min(max(1, proposed), maxColumns)
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnsCount), spacing: spacing) {
            ForEach(records) { record in
                RecordCover(colorHex: record.coverColorHex, photoData: record.photoData)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

struct AdaptiveRecordGrid: View {
    let records: [VinylRecord]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92, maximum: 140), spacing: 10)], spacing: 12) {
            ForEach(records) { record in
                NavigationLink {
                    RecordDetailView(record: record)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        RecordCover(colorHex: record.coverColorHex, photoData: record.photoData)
                            .aspectRatio(1, contentMode: .fit)
                        Text(record.title)
                            .font(.system(size: 11, design: .serif).weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(2)
                        Text(record.artist)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(AppTheme.inkFaint)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CreateCollectionView: View {
    let records: [VinylRecord]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var filterType: CollectionFilterType = .tag
    @State private var filterValue = ""
    @State private var errorText: String?

    private var suggestedValues: [String] {
        switch filterType {
        case .tag, .genre:
            return Array(Set(records.flatMap(\.tags))).sorted()
        case .label:
            return Array(Set(records.map(\.label).filter { !$0.isEmpty && $0 != "—" })).sorted()
        case .artist:
            return Array(Set(records.map(\.artist))).sorted()
        case .decade:
            return Array(Set(records.map { "\(($0.year / 10) * 10)" })).sorted()
        case .favorite:
            return ["favorite"]
        }
    }

    private var matchingCount: Int {
        let value = normalizedFilterValue()
        guard !value.isEmpty else { return 0 }
        return records.filter { record in
            switch filterType {
            case .favorite:
                return record.isFavorite
            case .tag:
                return record.tags.contains(value)
            case .genre:
                return record.tags.contains { $0.localizedCaseInsensitiveContains(value) }
            case .artist:
                return record.artist.localizedCaseInsensitiveCompare(value) == .orderedSame
            case .label:
                return record.label.localizedCaseInsensitiveCompare(value) == .orderedSame
            case .decade:
                return String((record.year / 10) * 10) == value
            }
        }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Например: Blue Note, 70-е, Любимые", text: $name)
                }

                Section("Фильтр") {
                    Picker("Тип", selection: $filterType) {
                        Text("Тег").tag(CollectionFilterType.tag)
                        Text("Жанр").tag(CollectionFilterType.genre)
                        Text("Артист").tag(CollectionFilterType.artist)
                        Text("Лейбл").tag(CollectionFilterType.label)
                        Text("Десятилетие").tag(CollectionFilterType.decade)
                        Text("Любимое").tag(CollectionFilterType.favorite)
                    }
                    .onChange(of: filterType) { _, newValue in
                        filterValue = newValue == .favorite ? "favorite" : ""
                    }

                    if filterType != .favorite {
                        TextField("Значение фильтра", text: $filterValue)
                    }

                    if !suggestedValues.isEmpty && filterType != .favorite {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(suggestedValues.prefix(20), id: \.self) { value in
                                    Button {
                                        filterValue = value
                                        if name.isEmpty { name = value }
                                    } label: {
                                        GoldChip(text: value, active: filterValue == value)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                Section {
                    Text("Совпадений: \(matchingCount)")
                        .foregroundStyle(matchingCount > 0 ? AppTheme.green : AppTheme.red)
                }

                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(AppTheme.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.bg)
            .navigationTitle("Новая коллекция")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.tint(AppTheme.gold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Создать") { create() }.tint(AppTheme.gold)
                }
            }
            .onAppear {
                if filterType == .favorite { filterValue = "favorite" }
            }
        }
    }

    private func create() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = normalizedFilterValue()

        guard !cleanName.isEmpty else {
            errorText = "Укажи название коллекции."
            return
        }
        guard !value.isEmpty else {
            errorText = "Укажи значение фильтра."
            return
        }

        let collection = SavedCollection(name: cleanName, filterType: filterType, filterValue: value)
        modelContext.insert(collection)
        try? modelContext.save()
        dismiss()
    }

    private func normalizedFilterValue() -> String {
        if filterType == .favorite { return "favorite" }
        return filterValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
