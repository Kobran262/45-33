import SwiftUI
import SwiftData
import UIKit

struct ShelfView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \VinylRecord.addedAt, order: .reverse) private var records: [VinylRecord]
    @Query(sort: \SavedCollection.createdAt, order: .reverse) private var collections: [SavedCollection]
    @Query private var profiles: [UserProfile]

    @AppStorage("ignoredCollectionSuggestionIDs") private var ignoredSuggestionIDsRaw = ""
    @AppStorage("shelfSortOrder") private var sortOrderRaw = ShelfSortOrder.addedNewest.rawValue
    @AppStorage("pendingShelfTagFilter") private var pendingShelfTagFilter = ""
    @AppStorage("pendingRecordDeepLink") private var pendingRecordDeepLink = ""
    @AppStorage("privateModeEnabled") private var privateModeEnabled = false
    @State private var filter: ShelfFilter = .all
    @State private var searchExpanded = false
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var showBatchSheet = false
    @State private var showMapSheet = false
    @State private var showProfileSheet = false
    @State private var showAddMenu = false
    @State private var collectionSuggestion: CollectionSuggestion?
    @State private var didCheckCollectionSuggestion = false
    @State private var selectedRecord: VinylRecord?
    @State private var isSelectionMode = false
    @State private var selectedRecordIDs: Set<UUID> = []
    @State private var showBulkDeleteConfirm = false
    @State private var showBulkTagSheet = false
    @State private var showFilterShowcase = false

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showAddSheet) { AddSingleView(mode: .shelf) }
            .sheet(isPresented: $showBatchSheet) { AddBatchView() }
            .sheet(isPresented: $showMapSheet) { VinylShopsMapView() }
            .sheet(isPresented: $showProfileSheet) { ProfileView() }
            .sheet(isPresented: $showBulkTagSheet) {
                BulkTagSheet { tag in
                    addTag(tag)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedRecord != nil },
                set: { if !$0 { selectedRecord = nil } }
            )) {
                if let selectedRecord {
                    RecordDetailView(record: selectedRecord)
                }
            }
            .navigationDestination(isPresented: $showFilterShowcase) {
                ShowcaseCollectionShareView(
                    records: filteredRecords,
                    title: filter.title,
                    handle: profileHandle,
                    captionTag: filter.title
                )
            }
            .confirmationDialog("Добавить", isPresented: $showAddMenu, titleVisibility: .hidden) {
                Button("По одной") { showAddSheet = true }
                Button("Сканировать стопку") { showBatchSheet = true }
                Button("Отмена", role: .cancel) {}
            }
            .alert("удалить выбранные?", isPresented: $showBulkDeleteConfirm) {
                Button("Удалить", role: .destructive) {
                    deleteSelectedRecords()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text(VoiceContent.phrase(
                    .confirmBulkDelete,
                    replacements: ["N": "\(selectedRecordIDs.count)"]
                ))
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
                applyPendingTagFilter()
                applyPendingRecordDeepLink()
                scheduleCollectionSuggestionIfNeeded()
            }
    }

    private var content: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            if records.isEmpty {
                emptyState
            } else {
                shelfContent
                    .overlay(alignment: .bottomTrailing) {
                        if !isSelectionMode {
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
                            .padding(.trailing, 18)
                            .padding(.bottom, 24)
                        }
                    }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isSelectionMode {
                Button("Готово") {
                    endSelection()
                }
                .tint(AppTheme.gold)
            } else {
                Button { showProfileSheet = true } label: {
                    Text(profileAvatar)
                        .font(.system(.subheadline, design: .serif).weight(.semibold))
                        .foregroundStyle(AppTheme.bg)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.gold)
                        .clipShape(Circle())
                }
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            if isSelectionMode {
                Text("\(selectedRecordIDs.count)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppTheme.inkMuted)
            } else {
                if !filter.isSame(.all) {
                    Button {
                        showFilterShowcase = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(AppTheme.gold)
                    }
                }

                Button("Выбрать") {
                    beginSelection()
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppTheme.gold)

                Menu {
                    ForEach(ShelfSortOrder.allCases) { order in
                        Button {
                            sortOrderRaw = order.rawValue
                        } label: {
                            Label(order.title, systemImage: sortOrderRaw == order.rawValue ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundStyle(AppTheme.inkMuted)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.panel)
                        .overlay(Circle().stroke(AppTheme.panelLine, lineWidth: 1))
                        .clipShape(Circle())
                }

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
    }

    private var profileAvatar: String { profiles.first?.avatarLetter ?? "M" }

    private var profileHandle: String {
        let raw = profiles.first?.handle.trimmingCharacters(in: .whitespacesAndNewlines)
        return (raw?.isEmpty == false ? raw! : "collector").replacingOccurrences(of: "@", with: "")
    }

    private var sortOrder: ShelfSortOrder {
        get { ShelfSortOrder(rawValue: sortOrderRaw) ?? .addedNewest }
        set { sortOrderRaw = newValue.rawValue }
    }

    private var filteredRecords: [VinylRecord] {
        let scoped = records.filter { $0.matchesFilter(filter) }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched = query.isEmpty ? scoped : scoped.filter { recordMatchesSearch($0, query: query) }
        return sort(searched)
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
        case .artistAscending:
            input.sorted { artistTitleSortKey($0).localizedStandardCompare(artistTitleSortKey($1)) == .orderedAscending }
        case .artistDescending:
            input.sorted { artistTitleSortKey($0).localizedStandardCompare(artistTitleSortKey($1)) == .orderedDescending }
        case .addedNewest:
            input.sorted { $0.addedAt > $1.addedAt }
        case .addedOldest:
            input.sorted { $0.addedAt < $1.addedAt }
        case .priceDescending:
            input.sorted { $0.price > $1.price }
        case .priceAscending:
            input.sorted { $0.price < $1.price }
        case .yearNewest:
            input.sorted { $0.year > $1.year }
        case .yearOldest:
            input.sorted { $0.year < $1.year }
        }
    }

    private func artistTitleSortKey(_ record: VinylRecord) -> String {
        "\(record.artist) \(record.title)"
    }

    private func recordMatchesSearch(_ record: VinylRecord, query: String) -> Bool {
        let words = query
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return true }

        let fields = [
            record.artist,
            record.title,
            record.label,
            record.story,
            record.pressing,
            String(record.year)
        ] + record.tags

        return words.allSatisfy { word in
            fields.contains { $0.localizedCaseInsensitiveContains(word) }
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

    private func applyPendingTagFilter() {
        let tag = pendingShelfTagFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        filter = .tag(tag)
        pendingShelfTagFilter = ""
    }

    private func applyPendingRecordDeepLink() {
        guard let id = UUID(uuidString: pendingRecordDeepLink),
              let record = records.first(where: { $0.id == id })
        else { return }
        selectedRecord = record
        pendingRecordDeepLink = ""
    }

    private func beginSelection(with record: VinylRecord? = nil) {
        isSelectionMode = true
        if let record {
            selectedRecordIDs.insert(record.id)
        }
    }

    private func endSelection() {
        isSelectionMode = false
        selectedRecordIDs.removeAll()
    }

    private func toggleSelection(_ record: VinylRecord) {
        if selectedRecordIDs.contains(record.id) {
            selectedRecordIDs.remove(record.id)
        } else {
            selectedRecordIDs.insert(record.id)
        }
    }

    private var selectedRecords: [VinylRecord] {
        records.filter { selectedRecordIDs.contains($0.id) }
    }

    private func deleteSelectedRecords() {
        selectedRecords.forEach { modelContext.delete($0) }
        try? modelContext.save()
        endSelection()
    }

    private func addTag(_ tag: String) {
        let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        for record in selectedRecords where !record.tags.contains(where: { $0.localizedCaseInsensitiveCompare(clean) == .orderedSame }) {
            record.tags.append(clean)
        }
        try? modelContext.save()
        endSelection()
    }

    private func moveSelectedToWishlist() {
        for record in selectedRecords {
            modelContext.insert(WishlistEntry(
                title: record.title,
                artist: record.artist,
                year: record.year == 0 ? nil : record.year,
                note: record.story
            ))
            modelContext.delete(record)
        }
        try? modelContext.save()
        endSelection()
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
        VStack(spacing: 14) {
            feltHeader
            if !isSelectionMode {
                tabsRow
                searchRow
            }
            listRows
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                        Text(latestSubtitle(latest))
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

    private var searchRow: some View {
        HStack(spacing: 10) {
            if searchExpanded {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.inkFaint)
                TextField("искать на полке", text: $searchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .foregroundStyle(AppTheme.ink)
                    .submitLabel(.search)
                Button {
                    searchText = ""
                    searchExpanded = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.inkFaint)
                }
            } else {
                Button {
                    searchExpanded = true
                } label: {
                    Label("поиск", systemImage: "magnifyingglass")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.gold)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, searchExpanded ? 10 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(AppTheme.panelLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .padding(.horizontal, 20)
    }

    private var listRows: some View {
        VStack(spacing: 0) {
            HStack {
                Text(filter.title.uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(AppTheme.inkFaint)
                Spacer()
                Text(sortOrder.shortTitle.uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.gold)
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if filteredRecords.isEmpty {
                Text(VoiceContent.phrase(.emptySearchResults))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.inkFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, 34)
                Spacer(minLength: 0)
            } else {
                ShelfRecyclerView(
                    records: filteredRecords,
                    isSelectionMode: isSelectionMode,
                    selectedIDs: selectedRecordIDs,
                    onSelect: { record in
                        if isSelectionMode {
                            toggleSelection(record)
                        } else {
                            selectedRecord = record
                        }
                    },
                    onLongPress: { record in
                        beginSelection(with: record)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isSelectionMode {
                bulkActionBar
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var bulkActionBar: some View {
        HStack(spacing: 8) {
            Button(role: .destructive) {
                if !selectedRecordIDs.isEmpty {
                    showBulkDeleteConfirm = true
                }
            } label: {
                Label("Удалить \(selectedRecordIDs.count)", systemImage: "trash")
            }
            .disabled(selectedRecordIDs.isEmpty)

            Button {
                if !selectedRecordIDs.isEmpty {
                    showBulkTagSheet = true
                }
            } label: {
                Label("Добавить тег…", systemImage: "tag")
            }
            .disabled(selectedRecordIDs.isEmpty)

            Button {
                if !selectedRecordIDs.isEmpty {
                    moveSelectedToWishlist()
                }
            } label: {
                Label("В вишлист", systemImage: "heart")
            }
            .disabled(selectedRecordIDs.isEmpty)
        }
        .font(.system(size: 11, design: .monospaced))
        .buttonStyle(.bordered)
        .tint(AppTheme.gold)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.panel)
    }

    private func latestSubtitle(_ record: VinylRecord) -> String {
        let price = record.formattedPrice.isEmpty ? "" : " · \(privateModeEnabled ? "\(record.currency)•••" : record.formattedPrice)"
        return "\(record.artist) · \(record.year)\(price)"
    }
}

private struct ShelfRecyclerView: UIViewRepresentable {
    let records: [VinylRecord]
    let isSelectionMode: Bool
    let selectedIDs: Set<UUID>
    let onSelect: (VinylRecord) -> Void
    let onLongPress: (VinylRecord) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            records: records,
            isSelectionMode: isSelectionMode,
            selectedIDs: selectedIDs,
            onSelect: onSelect,
            onLongPress: onLongPress
        )
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.scrollDirection = .vertical

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = UIColor(hex: "#211D18")
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(ShelfRecordCell.self, forCellWithReuseIdentifier: ShelfRecordCell.reuseID)
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        collectionView.addGestureRecognizer(longPress)
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.records = records
        context.coordinator.isSelectionMode = isSelectionMode
        context.coordinator.selectedIDs = selectedIDs
        context.coordinator.onSelect = onSelect
        context.coordinator.onLongPress = onLongPress
        collectionView.reloadData()
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        var records: [VinylRecord]
        var isSelectionMode: Bool
        var selectedIDs: Set<UUID>
        var onSelect: (VinylRecord) -> Void
        var onLongPress: (VinylRecord) -> Void

        init(
            records: [VinylRecord],
            isSelectionMode: Bool,
            selectedIDs: Set<UUID>,
            onSelect: @escaping (VinylRecord) -> Void,
            onLongPress: @escaping (VinylRecord) -> Void
        ) {
            self.records = records
            self.isSelectionMode = isSelectionMode
            self.selectedIDs = selectedIDs
            self.onSelect = onSelect
            self.onLongPress = onLongPress
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            records.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ShelfRecordCell.reuseID,
                for: indexPath
            ) as? ShelfRecordCell
            let record = records[indexPath.item]
            cell?.configure(
                with: record,
                isSelectionMode: isSelectionMode,
                isSelected: selectedIDs.contains(record.id)
            )
            return cell ?? UICollectionViewCell()
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            collectionView.deselectItem(at: indexPath, animated: true)
            onSelect(records[indexPath.item])
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let collectionView = gesture.view as? UICollectionView,
                  let indexPath = collectionView.indexPathForItem(at: gesture.location(in: collectionView))
            else { return }
            onLongPress(records[indexPath.item])
        }

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            CGSize(width: collectionView.bounds.width, height: 65)
        }
    }
}

private final class ShelfRecordCell: UICollectionViewCell {
    static let reuseID = "ShelfRecordCell"

    private let checkboxView = UIImageView()
    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let gradeLabel = UILabel()
    private let separator = UIView()
    private var coverLeadingConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        coverView.image = nil
        coverView.backgroundColor = UIColor(hex: "#3D362B")
        checkboxView.isHidden = true
    }

    func configure(with record: VinylRecord, isSelectionMode: Bool, isSelected: Bool) {
        if let photoData = record.photoData, let image = UIImage(data: photoData) {
            coverView.image = image
            coverView.backgroundColor = .clear
        } else {
            coverView.image = nil
            coverView.backgroundColor = UIColor(hex: record.coverColorHex) ?? UIColor(hex: "#5A4A7A")
        }

        titleLabel.text = record.title
        subtitleLabel.text = "\(record.artist) · \(record.year)"
        gradeLabel.text = record.grade.display
        checkboxView.isHidden = !isSelectionMode
        checkboxView.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        checkboxView.tintColor = isSelected ? UIColor(hex: "#C9A646") : UIColor(hex: "#8A7F6A")
        coverLeadingConstraint?.constant = isSelectionMode ? 54 : 22
    }

    private func setup() {
        backgroundColor = UIColor(hex: "#211D18")
        contentView.backgroundColor = UIColor(hex: "#211D18")

        checkboxView.contentMode = .scaleAspectFit
        checkboxView.tintColor = UIColor(hex: "#8A7F6A")
        checkboxView.isHidden = true
        checkboxView.translatesAutoresizingMaskIntoConstraints = false

        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = 8
        coverView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = UIFont.preferredSerifFont(forTextStyle: .callout, weight: .semibold)
        titleLabel.textColor = UIColor(hex: "#EAD9B6")
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = UIColor(hex: "#8A7F6A")
        subtitleLabel.numberOfLines = 1
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        gradeLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        gradeLabel.textColor = UIColor(hex: "#7FA86A")
        gradeLabel.textAlignment = .center
        gradeLabel.layer.borderColor = UIColor(hex: "#7FA86A")?.withAlphaComponent(0.4).cgColor
        gradeLabel.layer.borderWidth = 1
        gradeLabel.layer.cornerRadius = 3
        gradeLabel.translatesAutoresizingMaskIntoConstraints = false

        separator.backgroundColor = UIColor(hex: "#322C23")
        separator.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(checkboxView)
        contentView.addSubview(coverView)
        contentView.addSubview(textStack)
        contentView.addSubview(gradeLabel)
        contentView.addSubview(separator)

        coverLeadingConstraint = coverView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22)

        NSLayoutConstraint.activate([
            checkboxView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            checkboxView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkboxView.widthAnchor.constraint(equalToConstant: 22),
            checkboxView.heightAnchor.constraint(equalToConstant: 22),

            coverLeadingConstraint!,
            coverView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            coverView.widthAnchor.constraint(equalToConstant: 44),
            coverView.heightAnchor.constraint(equalToConstant: 44),

            textStack.leadingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: gradeLabel.leadingAnchor, constant: -12),

            gradeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            gradeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            gradeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 34),
            gradeLabel.heightAnchor.constraint(equalToConstant: 20),

            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 78),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
}

private extension UIFont {
    static func preferredSerifFont(forTextStyle textStyle: TextStyle, weight: Weight) -> UIFont {
        let preferred = UIFont.preferredFont(forTextStyle: textStyle)
        let descriptor = preferred.fontDescriptor.withDesign(.serif) ?? preferred.fontDescriptor
        return UIFont(descriptor: descriptor, size: preferred.pointSize).withWeight(weight)
    }

    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

private extension UIColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&rgb) else { return nil }
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255,
            blue: CGFloat(rgb & 0x0000FF) / 255,
            alpha: 1
        )
    }
}

private struct BulkTagSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tag = ""
    let onCommit: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Тег") {
                    TextField("например: джаз", text: $tag)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
            }
            .navigationTitle("добавить тег")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        onCommit(tag)
                        dismiss()
                    }
                    .disabled(tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private enum ShelfSortOrder: String, CaseIterable, Identifiable {
    case addedNewest
    case addedOldest
    case artistAscending
    case artistDescending
    case priceDescending
    case priceAscending
    case yearNewest
    case yearOldest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addedNewest: "Сначала новые добавления"
        case .addedOldest: "Сначала старые добавления"
        case .artistAscending: "А-Я (артист)"
        case .artistDescending: "Я-А (артист)"
        case .priceDescending: "Дороже"
        case .priceAscending: "Дешевле"
        case .yearNewest: "Год выпуска: новые"
        case .yearOldest: "Год выпуска: старые"
        }
    }

    var shortTitle: String {
        switch self {
        case .addedNewest: "недавние"
        case .addedOldest: "давние"
        case .artistAscending: "А-Я артист"
        case .artistDescending: "Я-А артист"
        case .priceDescending: "дороже"
        case .priceAscending: "дешевле"
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
