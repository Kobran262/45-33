import SwiftUI
import SwiftData

struct ShowcaseCardSettings {
    var title: String
    var subtitle: String = ""
    var handle: String
    var showStory: Bool = true
    var showStats: Bool = true
    var cardStyle: CardStyle = .table
    var collectionMetric: CollectionMetric = .topGenre

    enum CardStyle: String, CaseIterable, Identifiable {
        case table
        case paper
        case magazine
        case neon
        case minimalMono
        case polaroid

        var id: String { rawValue }

        var label: String {
            switch self {
            case .table: "Стол"
            case .paper: "Бумага"
            case .magazine: "Журнал"
            case .neon: "Неон"
            case .minimalMono: "Минимал-моно"
            case .polaroid: "Поляроид"
            }
        }

        var isPro: Bool {
            switch self {
            case .table, .paper: false
            case .magazine, .neon, .minimalMono, .polaroid: true
            }
        }
    }

    enum CollectionMetric: String, CaseIterable, Identifiable {
        case topGenre
        case topArtist
        case favorites
        case totalValue

        var id: String { rawValue }

        var label: String {
            switch self {
            case .topGenre: "Топ-жанр"
            case .topArtist: "Топ-артист"
            case .favorites: "Любимые"
            case .totalValue: "Сумма"
            }
        }
    }
}

struct ShowcaseRecordView: View {
    let record: VinylRecord

    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var sharePayload: SharePayload?
    @State private var showSettings = false
    @State private var settings = ShowcaseCardSettings(title: "", handle: "")

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("предпросмотр карточки".uppercased())
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.inkFaint)
                    .padding(.top, 8)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ShowcaseStyleStrip(settings: $settings)
                        shareCard
                    }
                    .padding(.bottom, 8)
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
                        shareRecordPNG()
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }.tint(AppTheme.gold)
                }
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
            .sheet(isPresented: $showSettings) {
                ShowcaseCardSettingsView(settings: $settings) {
                    VoiceContent.phrase(.vitrinaCaptionRecord)
                }
            }
            .onAppear {
                if settings.title.isEmpty {
                    settings.title = record.title
                }
                if settings.handle.isEmpty {
                    settings.handle = profileHandle
                }
            }
        }
    }

    @ViewBuilder
    private var shareCard: some View {
        RecordShareCard(record: record, settings: settings)
            .padding(.horizontal, 20)
    }

    private var profileHandle: String {
        let raw = profiles.first?.handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "collector"
        return (raw?.isEmpty == false ? raw! : fallback).replacingOccurrences(of: "@", with: "")
    }

    @MainActor
    private func shareRecordPNG() {
        let exportSettings = normalizedSettings()
        let url = SharePNGExporter.temporaryPNGURL(
            filename: "\(record.artist)-\(record.title)",
            width: 340
        ) {
            RecordShareCard(record: record, settings: exportSettings)
        }

        if let url {
            sharePayload = SharePayload(items: [url])
        }
    }

    private func normalizedSettings() -> ShowcaseCardSettings {
        var copy = settings
        if copy.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.title = record.title
        }
        if copy.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.handle = profileHandle
        }
        copy.handle = copy.handle.replacingOccurrences(of: "@", with: "")
        return copy
    }
}

struct RecordShareCard: View {
    let record: VinylRecord
    let settings: ShowcaseCardSettings

    var body: some View {
        VStack(spacing: settings.cardStyle == .magazine ? 16 : 14) {
            cover
                .padding(.top, 22)

            VStack(spacing: 6) {
                Text(settings.title)
                    .font(titleFont)
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)

                Text(settings.subtitle.isEmpty ? record.artist : settings.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(palette.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 18)

            if settings.showStats {
                HStack(spacing: 22) {
                    stat("ГОД", "\(record.year)")
                    if record.pressing != "—" {
                        stat("ПРЕССИНГ", record.pressing.split(separator: "·").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? "")
                    }
                    if record.label != "—" {
                        stat("ЛЕЙБЛ", record.label)
                    }
                }
            }

            if settings.showStory && !record.story.isEmpty {
                Text("«\(record.story.replacingOccurrences(of: "«", with: "").replacingOccurrences(of: "»", with: ""))»")
                    .italic()
                    .font(.system(.footnote, design: .serif))
                    .foregroundStyle(palette.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            footer(handle: settings.handle)
        }
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(palette.bg)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerCard)
                .stroke(palette.border, lineWidth: settings.cardStyle == .magazine ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerCard))
    }

    @ViewBuilder
    private var cover: some View {
        let size: CGFloat = settings.cardStyle == .magazine ? 210 : 180

        if settings.cardStyle == .polaroid {
            VStack(spacing: 8) {
                RecordCover(colorHex: record.coverColorHex, photoData: record.photoData)
                    .frame(width: size, height: size)
                Text(record.artist)
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(palette.muted)
                    .padding(.bottom, 24)
            }
            .padding(.top, 10)
            .padding(.horizontal, 10)
            .background(Color(hex: "#FFFFFF"))
            .rotationEffect(.degrees(-1.5))
            .shadow(color: .black.opacity(0.2), radius: 18, y: 12)
        } else {
            RecordCover(colorHex: record.coverColorHex, photoData: record.photoData)
                .frame(width: size, height: size)
                .shadow(color: settings.cardStyle == .neon ? Color(hex: "#FF4D8F").opacity(0.3) : .black.opacity(0.4), radius: settings.cardStyle == .neon ? 30 : 14, y: 8)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(palette.muted)
            Text(value)
                .font(.caption)
                .foregroundStyle(palette.accent)
                .lineLimit(1)
        }
    }

    private func footer(handle: String) -> some View {
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
        .padding(.top, 8)
        .padding(.bottom, 12)
        .overlay(
            Rectangle()
                .fill(palette.border)
                .frame(height: 1)
                .padding(.horizontal, 18),
            alignment: .top
        )
    }

    private var titleFont: Font {
        switch settings.cardStyle {
        case .magazine:
            .system(.largeTitle, design: .serif).weight(.regular)
        case .minimalMono:
            .system(.title2, design: .default).weight(.bold)
        case .polaroid:
            .system(.title2, design: .serif).weight(.semibold)
        default:
            .system(settings.cardStyle == .paper ? .title2 : .title2, design: .serif).weight(.semibold)
        }
    }

    private var palette: ShowcasePalette {
        ShowcasePalette(style: settings.cardStyle)
    }
}

struct ShowcaseCardSettingsView: View {
    @Binding var settings: ShowcaseCardSettings
    var suggestedCaption: (() -> String)?
    @Environment(\.dismiss) private var dismiss

    init(settings: Binding<ShowcaseCardSettings>, suggestedCaption: (() -> String)? = nil) {
        self._settings = settings
        self.suggestedCaption = suggestedCaption
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Текст") {
                    TextField("Заголовок", text: $settings.title)
                    TextField("Подзаголовок", text: $settings.subtitle)
                    TextField("Ник автора", text: $settings.handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    if let suggestedCaption {
                        Button("Предложить подпись") {
                            settings.subtitle = suggestedCaption()
                        }
                        .tint(AppTheme.gold)
                    }
                }

                Section("Вид") {
                    Picker("Стиль", selection: $settings.cardStyle) {
                        ForEach(ShowcaseCardSettings.CardStyle.allCases) { style in
                            Text(style.isPro ? "\(style.label) · PRO" : style.label).tag(style)
                        }
                    }
                    Picker("Метрика коллекции", selection: $settings.collectionMetric) {
                        ForEach(ShowcaseCardSettings.CollectionMetric.allCases) { metric in
                            Text(metric.label).tag(metric)
                        }
                    }
                    Toggle("Показывать статистику", isOn: $settings.showStats)
                    Toggle("Показывать историю", isOn: $settings.showStory)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.bg)
            .navigationTitle("Настройка карточки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }.tint(AppTheme.gold)
                }
            }
        }
    }
}

struct ShowcaseStyleStrip: View {
    @Binding var settings: ShowcaseCardSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("стиль перед отправкой".uppercased())
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.inkFaint)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ShowcaseCardSettings.CardStyle.allCases) { style in
                        Button {
                            settings.cardStyle = style
                        } label: {
                            GoldChip(
                                text: style.isPro ? "\(style.label) · PRO" : style.label,
                                active: settings.cardStyle == style
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Toggle("Статистика", isOn: $settings.showStats)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.inkMuted)
                .tint(AppTheme.gold)
        }
        .padding(14)
        .background(AppTheme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.panelLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = controller.view
        controller.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ShowcasePalette {
    let bg: Color
    let border: Color
    let ink: Color
    let muted: Color
    let accent: Color

    init(style: ShowcaseCardSettings.CardStyle) {
        switch style {
        case .table:
            bg = Color(hex: "#1A1712")
            border = AppTheme.panelLine
            ink = AppTheme.ink
            muted = AppTheme.inkFaint
            accent = AppTheme.gold
        case .paper:
            bg = Color(hex: "#ECE7DD")
            border = Color(hex: "#B8B1A0")
            ink = Color(hex: "#232019")
            muted = Color(hex: "#86806F")
            accent = Color(hex: "#B04A2A")
        case .magazine:
            bg = Color(hex: "#ECE7DD")
            border = Color(hex: "#232019")
            ink = Color(hex: "#232019")
            muted = Color(hex: "#86806F")
            accent = Color(hex: "#B04A2A")
        case .neon:
            bg = Color(hex: "#1A1530")
            border = Color(hex: "#2E2855")
            ink = Color(hex: "#F5E1FF")
            muted = Color(hex: "#8A82A5")
            accent = Color(hex: "#FF4D8F")
        case .minimalMono:
            bg = Color(hex: "#F4F4F4")
            border = Color(hex: "#1A1A1A")
            ink = Color(hex: "#1A1A1A")
            muted = Color(hex: "#6B6B6B")
            accent = Color(hex: "#1A1A1A")
        case .polaroid:
            bg = Color(hex: "#FBFAF5")
            border = Color(hex: "#FFFFFF")
            ink = Color(hex: "#2A2218")
            muted = Color(hex: "#8A8170")
            accent = AppTheme.gold
        }
    }
}
