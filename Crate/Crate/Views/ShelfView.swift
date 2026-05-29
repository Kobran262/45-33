import SwiftUI
import SwiftData

struct ShelfView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \VinylRecord.addedAt, order: .reverse) private var records: [VinylRecord]
    @Query(sort: \SavedCollection.createdAt, order: .reverse) private var collections: [SavedCollection]
    @Query private var profiles: [UserProfile]

    @AppStorage("ignoredCollectionSuggestionIDs") private var ignoredSuggestionIDsRaw = ""
    @State private var filter: ShelfFilter = .all
    @State private var sortOrder: ShelfSortOrder = .addedNewest
    @State private var showAddSheet = false
    @State private var showBatchSheet = false
    @State private var showMapSheet = false
    @State private var showProfileSheet = false
    @State private var showAddMenu = false
    @State private var collectionSuggestion: CollectionSuggestion?
    @State private var didCheckCollectionSuggestion = false

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            if records.isEmpty {
                emptyState
            } else {
                shelfContent
            }

            if !records.isEmpty {
                Button {
                    showAddMenu = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.bg)
                        .frame(width: 56, height: 56)
                        .background(AppTheme.gold)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.gold.opacity(0.4), radius: 12, y: 6)
                }
                .position(x: UIScreen.main.bounds.width - 50, y: UIScreen.main.bounds.height - 200)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showProfileSheet = true } label: {
                    Text(profileAvatar)
                        .font(.system(.subheadline, design: .serif).weight(.semibold))
                        .foregroundStyle(AppTheme.bg)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.gold)
                        .clipShape(Circle())
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button { showMapSheet = true } label: {
                    Image(systemName: "scope")
                        .foregroundStyle(AppTheme.inkMuted)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.panel)
                        .overlay(Circle().stroke(AppTheme.panelLine, lineWidth: 1))
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $showAddSheet) { AddSingleView(mode: .shelf) }
        .sheet(isPresented: $showBatchSheet) { AddBatchView() }
        .sheet(isPresented: $showMapSheet) { VinylShopsMapView() }
        .sheet(isPresented: $showProfileSheet) { ProfileView() }
        .confirmationDialog("Добавить", isPresented: $showAddMenu, titleVisibility: .hidden) {
            Button("По одной") { showAddSheet = true }
            Button("Сканировать стопку") { showBatchSheet = true }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Собрать подборку?", isPresented: Binding(
            get: { collectionSuggestion != nil },
            set: { if !$0 { collectionSuggestion = nil } }
        ), presenting: collectionSuggestion) { suggestion in
            Button("да") {
                createSuggestedCollection(suggestion)
            }
            Button("пока нет", role: .cancel) {
                collectionSuggestion = nil
            }
            Button("больше не спрашивай", role: .destructive) {
                ignoreSuggestion(suggestion)
            }
        } message: { suggestion in
            Text(suggestion.body)
        }
        .onAppear {
            scheduleCollectionSuggestionIfNeeded()
        }
    }

    private var profileAvatar: String { profiles.first?.avatarLetter ?? "M" }

    private var filteredRecords: [VinylRecord] {
        sort(records.filter { $0.matchesFilter(filter) })
    }

    private var availableTags: [String] {
        let ignored = Set(["любимое", "favorite", "—", ""])
        let values = records
            .flatMap(\.tags)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !ignored.contains($0.lowercased()) }
        return Array(Set(values)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func sort(_ input: [VinylRecord]) -> [VinylRecord] {
        switch sortOrder {
        case .titleAscending:
            input.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .titleDescending:
            input.sorted { $0.title.localizedStandardCompare($1.title) == .orderedDescending }
        case .addedNewest:
            input.sorted { $0.addedAt > $1.addedAt }
        case .addedOldest:
            input.sorted { $0.addedAt < $1.addedAt }
        case .yearNewest:
            input.sorted { $0.year > $1.year }
        case .yearOldest:
            input.sorted { $0.year < $1.year }
        }
    }

    private var ignoredSuggestionIDs: Set<String> {
        Set(ignoredSuggestionIDsRaw.split(separator: "|").map(String.init))
    }

    private func scheduleCollectionSuggestionIfNeeded() {
        guard !didCheckCollectionSuggestion else { return }
        didCheckCollectionSuggestion = true

        guard let suggestion = SuggestionsEngine.shelfPrompt(
            records: records,
            existing: collections,
            ignoredIDs: ignoredSuggestionIDs
        ) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if collectionSuggestion == nil {
                collectionSuggestion = suggestion
            }
        }
    }

    private func createSuggestedCollection(_ suggestion: CollectionSuggestion) {
        let collection = SavedCollection(
            name: suggestion.title,
            filterType: suggestion.filterType,
            filterValue: suggestion.filterValue
        )
        modelContext.insert(collection)
        try? modelContext.save()
        filter = .collection(collection)
        collectionSuggestion = nil
    }

    private func ignoreSuggestion(_ suggestion: CollectionSuggestion) {
        var ids = ignoredSuggestionIDs
        ids.insert(suggestion.id)
        ignoredSuggestionIDsRaw = ids.sorted().joined(separator: "|")
        collectionSuggestion = nil
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(AppTheme.panel).frame(width: 120, height: 120)
                Circle().fill(AppTheme.gold).frame(width: 40, height: 40)
                Circle().fill(AppTheme.bg).frame(width: 14, height: 14)
            }

            VStack(spacing: 10) {
                Text("Полка пока пуста")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(VoiceContent.phrase(.emptyShelfFirst))
                    .italic()
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(AppTheme.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
            }

            VStack(spacing: 10) {
                Button {
                    showAddSheet = true
                } label: {
                    Text("＋ добавить первую пластинку")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.gold)

                Button {
                    showBatchSheet = true
                } label: {
                    Text("▦ отсканировать стопку")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.inkMuted)
            }
            .font(.system(size: 11, design: .monospaced))
            .padding(.horizontal, 34)
        }
    }

    private var shelfContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                feltHeader
                tabsRow
                listRows
            }
            .padding(.bottom, 100)
        }
    }

    private var feltHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("коллекция · \(records.count) пластинок".uppercased())
                .font(.system(size: 9, design: .monospaced))
                .tracking(2)
                .foregroundStyle(AppTheme.inkFaint)
            Text("На столе")
                .font(.system(.title, design: .serif).weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            if let latest = records.first {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(AppTheme.bgDeep).frame(width: 74, height: 74)
                        Circle().fill(AppTheme.gold).frame(width: 24, height: 24)
                        Circle().fill(AppTheme.bg).frame(width: 8, height: 8)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ПОСЛЕДНЕЕ ДОБАВЛЕНО")
                            .font(.system(size: 9, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(AppTheme.inkFaint)
                        Text(latest.title)
                            .font(.system(.subheadline, design: .serif).weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text("\(latest.artist) · \(latest.year)\(latest.formattedPrice.isEmpty ? "" : " · \(latest.formattedPrice)")")
                            .font(.caption)
                            .foregroundStyle(AppTheme.inkMuted)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .feltPanel()
        .padding(.horizontal, 16)
    }

    private var tabsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                Button { filter = .all } label: {
                    GoldChip(text: ShelfFilter.all.title, active: filter.isSame(.all))
                }
                Button { filter = .favorite } label: {
                    GoldChip(text: ShelfFilter.favorite.title, active: filter.isSame(.favorite))
                }
                ForEach(availableTags, id: \.self) { tag in
                    Button { filter = .tag(tag) } label: {
                        GoldChip(text: tag, active: filter.isSame(.tag(tag)))
                    }
                }
                ForEach(collections) { col in
                    Button {
                        filter = .collection(col)
                    } label: {
                        GoldChip(text: col.name, active: filter.isSame(.collection(col)))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var listRows: some View {
        VStack(spacing: 0) {
            HStack {
                Text(filter.title.uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(AppTheme.inkFaint)
                Spacer()
                Menu {
                    ForEach(ShelfSortOrder.allCases) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            Label(order.title, systemImage: sortOrder == order ? "checkmark" : "")
                        }
                    }
                } label: {
                    Text(sortOrder.shortTitle.uppercased())
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.gold)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ForEach(filteredRecords) { record in
                NavigationLink {
                    RecordDetailView(record: record)
                } label: {
                    HStack(spacing: 12) {
                        RecordCover(colorHex: record.coverColorHex, photoData: record.photoData)
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.title)
                                .font(.system(.callout, design: .serif).weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text("\(record.artist) · \(record.year)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.inkFaint)
                        }
                        Spacer()
                        Text(record.grade.display)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(AppTheme.green)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3).stroke(AppTheme.green.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 22)
                }
                .buttonStyle(.plain)
                Rectangle().fill(AppTheme.rowLine).frame(height: 1).padding(.leading, 78)
            }
        }
    }
}

private enum ShelfSortOrder: String, CaseIterable, Identifiable {
    case titleAscending
    case titleDescending
    case addedNewest
    case addedOldest
    case yearNewest
    case yearOldest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .titleAscending: "Название А-Я"
        case .titleDescending: "Название Я-А"
        case .addedNewest: "Сначала новые добавления"
        case .addedOldest: "Сначала старые добавления"
        case .yearNewest: "Год выпуска: новые"
        case .yearOldest: "Год выпуска: старые"
        }
    }

    var shortTitle: String {
        switch self {
        case .titleAscending: "А-Я"
        case .titleDescending: "Я-А"
        case .addedNewest: "добавлено ↓"
        case .addedOldest: "добавлено ↑"
        case .yearNewest: "год ↓"
        case .yearOldest: "год ↑"
        }
    }
}

private extension ShelfFilter {
    func isSame(_ other: ShelfFilter) -> Bool {
        switch (self, other) {
        case (.all, .all), (.favorite, .favorite):
            true
        case (.tag(let left), .tag(let right)):
            left.localizedCaseInsensitiveCompare(right) == .orderedSame
        case (.collection(let left), .collection(let right)):
            left.id == right.id
        default:
            false
        }
    }
}
