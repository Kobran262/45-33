import SwiftUI
import SwiftData

struct EditRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var record: VinylRecord
    @State private var title: String = ""
    @State private var artist: String = ""
    @State private var year: Int = 1970
    @State private var label: String = ""
    @State private var pressing: String = ""
    @State private var gradeRaw: String = RecordGrade.VGPlus.rawValue
    @State private var vinylColorRaw: String = VinylColor.black.rawValue
    @State private var story: String = ""
    @State private var tagsString: String = ""
    @State private var priceString: String = ""

    var body: some View {
        Form {
            Section("Основное") {
                TextField("Альбом", text: $title)
                TextField("Артист", text: $artist)
                Stepper("Год: \(year)", value: $year, in: 1900...2100)
                TextField("Лейбл", text: $label)
                TextField("Прессинг", text: $pressing)
            }

            Section("Состояние и винил") {
                Picker("Состояние", selection: $gradeRaw) {
                    ForEach(RecordGrade.allCases, id: \.rawValue) { g in
                        Text(g.display).tag(g.rawValue)
                    }
                }
                Picker("Цвет винила", selection: $vinylColorRaw) {
                    ForEach(VinylColor.allCases, id: \.rawValue) { c in
                        Text(c.label).tag(c.rawValue)
                    }
                }
            }

            Section("Цена") {
                TextField("Цена (€)", text: $priceString)
                    .keyboardType(.decimalPad)
            }

            Section("Теги") {
                TextField("через запятую", text: $tagsString)
            }

            Section("История") {
                TextEditor(text: $story)
                    .frame(minHeight: 100)
            }
        }
        .navigationTitle("Редактирование")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Готово") {
                    saveDraft()
                    dismiss()
                }
                .tint(AppTheme.gold)
            }
        }
        .onAppear {
            title = record.title
            artist = record.artist
            year = record.year
            label = record.label
            pressing = record.pressing
            gradeRaw = record.gradeRaw
            vinylColorRaw = record.vinylColorRaw
            story = record.story
            tagsString = record.tags.joined(separator: ", ")
            priceString = record.price > 0 ? String(Int(record.price)) : ""
        }
    }

    private func saveDraft() {
        record.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        record.year = year
        record.label = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : label
        record.pressing = pressing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : pressing
        record.gradeRaw = gradeRaw
        record.vinylColorRaw = vinylColorRaw
        record.price = Double(priceString.replacingOccurrences(of: ",", with: ".")) ?? 0
        record.tags = tagsString.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        record.story = story
        try? modelContext.save()
    }
}
