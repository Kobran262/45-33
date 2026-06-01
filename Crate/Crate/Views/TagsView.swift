import SwiftUI
import SwiftData

struct TagsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VinylRecord.addedAt, order: .reverse) private var records: [VinylRecord]
    @AppStorage("pendingShelfTagFilter") private var pendingShelfTagFilter = ""

    let onOpenShelf: () -> Void

    @State private var selectedTag: String?
    @State private var renameText = ""
    @State private var showRenameSheet = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            WrapLayout(spacing: 8) {
                ForEach(tagStats, id: \.name) { stat in
                    Button {
                        pendingShelfTagFilter = stat.name
                        onOpenShelf()
                    } label: {
                        Text(stat.name)
                            .font(.system(size: fontSize(for: stat.count), design: .serif).weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.panel)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).stroke(AppTheme.panelLine, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .contextMenu {
                        Button("Переименовать тег") {
                            selectedTag = stat.name
                            renameText = stat.name
                            showRenameSheet = true
                        }
                        Button("Удалить тег у всех", role: .destructive) {
                            selectedTag = stat.name
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("мои теги")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRenameSheet) {
            NavigationStack {
                Form {
                    Section("Новое имя") {
                        TextField("тег", text: $renameText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                }
                .navigationTitle("переименовать")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { showRenameSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") {
                            renameSelectedTag()
                        }
                        .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .alert("удалить тег?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) {
                deleteSelectedTag()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Тег будет убран у \(selectedTagCount) пластинок.")
        }
    }

    private var tagStats: [TagStat] {
        var counts: [String: Int] = [:]
        for tag in records.flatMap(\.tags) {
            let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, clean != "—" else { continue }
            counts[clean, default: 0] += 1
        }
        return counts
            .map { TagStat(name: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.count > $1.count
            }
    }

    private var selectedTagCount: Int {
        guard let selectedTag else { return 0 }
        return records.filter { $0.tags.contains(selectedTag) }.count
    }

    private func fontSize(for count: Int) -> CGFloat {
        min(24, 12 + CGFloat(count) * 2)
    }

    private func renameSelectedTag() {
        guard let selectedTag else { return }
        let clean = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        for record in records where record.tags.contains(selectedTag) {
            record.tags = record.tags.map { $0 == selectedTag ? clean : $0 }
        }
        try? modelContext.save()
        showRenameSheet = false
        self.selectedTag = nil
    }

    private func deleteSelectedTag() {
        guard let selectedTag else { return }
        for record in records where record.tags.contains(selectedTag) {
            record.tags.removeAll { $0 == selectedTag }
        }
        try? modelContext.save()
        self.selectedTag = nil
    }
}

private struct TagStat {
    let name: String
    let count: Int
}
