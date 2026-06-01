import SwiftUI
import WidgetKit

struct WidgetRecordSnapshot: Codable, Identifiable {
    var id: UUID
    var title: String
    var artist: String
    var coverColorHex: String
    var photoDataBase64: String?
    var addedAt: Date
}

struct RecentRecordsEntry: TimelineEntry {
    let date: Date
    let records: [WidgetRecordSnapshot]
}

struct RecentRecordsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentRecordsEntry {
        RecentRecordsEntry(date: .now, records: [.placeholder])
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentRecordsEntry) -> Void) {
        completion(RecentRecordsEntry(date: .now, records: loadRecords()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentRecordsEntry>) -> Void) {
        let entry = RecentRecordsEntry(date: .now, records: loadRecords())
        completion(Timeline(entries: [entry], policy: .atEnd))
    }

    private func loadRecords() -> [WidgetRecordSnapshot] {
        let defaults = UserDefaults(suiteName: "group.com.crate.vinyl") ?? .standard
        guard let data = defaults.data(forKey: "recentRecordSnapshots"),
              let records = try? JSONDecoder().decode([WidgetRecordSnapshot].self, from: data)
        else { return [.placeholder] }
        return Array(records.prefix(4))
    }
}

struct CrateWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RecentRecordsProvider.Entry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        let record = entry.records.first ?? .placeholder
        return VStack(alignment: .leading, spacing: 8) {
            cover(for: record)
                .frame(width: 54, height: 54)
            Text(record.title)
                .font(.headline)
                .lineLimit(2)
            Text(record.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .widgetURL(URL(string: "crate://record/\(record.id.uuidString)"))
        .containerBackground(Color(red: 0.13, green: 0.11, blue: 0.09), for: .widget)
    }

    private var mediumView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
            ForEach(entry.records.prefix(4)) { record in
                HStack(spacing: 8) {
                    cover(for: record)
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(record.artist)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .containerBackground(Color(red: 0.13, green: 0.11, blue: 0.09), for: .widget)
    }

    @ViewBuilder
    private func cover(for record: WidgetRecordSnapshot) -> some View {
        if let base64 = record.photoDataBase64,
           let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 7))
        } else {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(hex: record.coverColorHex))
        }
    }
}

@main
struct CrateWidget: Widget {
    let kind = "CrateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentRecordsProvider()) { entry in
            CrateWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("45/33")
        .description("Последние пластинки на полке.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private extension WidgetRecordSnapshot {
    static let placeholder = WidgetRecordSnapshot(
        id: UUID(),
        title: "Kind of Blue",
        artist: "Miles Davis",
        coverColorHex: "#5a4a7a",
        photoDataBase64: nil,
        addedAt: .now
    )
}

private extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: value).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }
}
