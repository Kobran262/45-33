import SwiftUI
import SwiftData
import Charts

struct YearlyRecapView: View {
    @Query(sort: \VinylRecord.addedAt, order: .reverse) private var records: [VinylRecord]
    @Query(sort: \Achievement.unlockedAt, order: .reverse) private var achievements: [Achievement]
    @Query private var profiles: [UserProfile]

    @AppStorage("privateModeEnabled") private var privateModeEnabled = false
    @State private var selectedPeriod: RecapPeriod = .rolling12Months
    @State private var sharePayload: SharePayload?

    private var availablePeriods: [RecapPeriod] {
        YearlyRecapService.availablePeriods(from: records)
    }

    private var recap: YearlyRecap {
        YearlyRecapService.generate(
            period: selectedPeriod,
            records: records,
            achievements: achievements
        )
    }

    private var handle: String {
        let raw = profiles.first?.handle ?? ""
        return raw.isEmpty ? "" : "@\(raw.replacingOccurrences(of: "@", with: ""))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                periodPicker
                heroSection
                spentSection
                topGenresSection
                topArtistsSection
                topLabelsSection
                decadesSection
                storySection
                achievementsSection
                monthlySection
                shareButton
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("Год в виниле")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedPeriod = YearlyRecapService.defaultPeriod(from: records)
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
    }

    private var periodPicker: some View {
        Picker("Период", selection: $selectedPeriod) {
            ForEach(availablePeriods, id: \.self) { period in
                Text(period.displayTitle).tag(period)
            }
        }
        .pickerStyle(.menu)
        .tint(AppTheme.gold)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recap.period.displayTitle)
                .font(.system(.title, design: .serif).weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Text("\(recap.totalRecords)")
                .font(.system(size: 56, design: .serif).weight(.bold))
                .foregroundStyle(AppTheme.gold)
            Text("пластинок на полке за период")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.inkFaint)
            Text(VoiceContent.recapHero(count: recap.totalRecords))
                .font(.callout)
                .foregroundStyle(AppTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(recapPanel)
    }

    private var spentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("вложено".uppercased())
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.inkFaint)
            Text(spentDisplay)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Text(VoiceContent.summaryTotalSpent(
                sum: spentDisplay,
                amount: recap.totalSpent
            ))
            .font(.callout)
            .foregroundStyle(AppTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(recapPanel)
    }

    private var spentDisplay: String {
        if privateModeEnabled { return "\(recap.currency)•••" }
        if recap.totalSpent <= 0 { return "—" }
        return String(format: "%@%.0f", recap.currency, recap.totalSpent)
    }

    private var topGenresSection: some View {
        topListSection(
            title: VoiceContent.recapPhrase(.recapTopGenreIntro),
            items: recap.topGenres.map { ($0.name, $0.count) },
            empty: "Жанры за период не накопились."
        )
    }

    private var topArtistsSection: some View {
        topListSection(
            title: VoiceContent.recapPhrase(.recapTopArtistIntro),
            items: recap.topArtists.map { ($0.name, $0.count) },
            empty: "Артисты за период не выделились."
        )
    }

    private var topLabelsSection: some View {
        topListSection(
            title: VoiceContent.recapPhrase(.recapTopLabelIntro),
            items: recap.topLabels.map { ($0.name, $0.count) },
            empty: "Лейблы за период не считались."
        )
    }

    private func topListSection(title: String, items: [(String, Int)], empty: String) -> some View {
        let maxCount = items.map(\.1).max() ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.inkFaint)
            if items.isEmpty {
                Text(empty)
                    .font(.callout)
                    .foregroundStyle(AppTheme.inkMuted)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(item.0) · \(item.1) пластинок")
                            .font(.callout)
                            .foregroundStyle(AppTheme.inkSoft)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppTheme.gold)
                                .frame(width: geo.size.width * CGFloat(item.1) / CGFloat(max(1, maxCount)))
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(recapPanel)
    }

    private var decadesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("по десятилетиям")
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.inkFaint)
            if recap.decadeDistribution.isEmpty {
                Text("За период нет данных по годам издания.")
                    .font(.callout)
                    .foregroundStyle(AppTheme.inkMuted)
            } else {
                Chart(recap.decadeDistribution, id: \.decade) { item in
                    BarMark(
                        x: .value("Десятилетие", "\(item.decade)"),
                        y: .value("Количество", item.count)
                    )
                    .foregroundStyle(AppTheme.gold.gradient)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(recapPanel)
    }

    private var storySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("сюжет года")
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.inkFaint)
            storyCard(
                title: VoiceContent.recapPhrase(.recapMostExpensive),
                record: recap.mostExpensive
            )
            storyCard(
                title: VoiceContent.recapPhrase(.recapOldestPress),
                record: recap.oldestPress,
                subtitle: recap.oldestPress.map { "\($0.year)" }
            )
            storyCard(title: "первая в этом периоде", record: recap.firstAdded, subtitle: recap.firstAdded.map { $0.addedAt.formatted(date: .abbreviated, time: .omitted) })
            storyCard(title: "последняя", record: recap.lastAdded, subtitle: recap.lastAdded.map { $0.addedAt.formatted(date: .abbreviated, time: .omitted) })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(recapPanel)
    }

    private func storyCard(title: String, record: VinylRecord?, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AppTheme.inkFaint)
            if let record {
                HStack(spacing: 12) {
                    RecordCover(colorHex: record.coverColorHex, photoData: record.photoData)
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.artist)
                            .font(.system(.subheadline, design: .serif).weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text(record.title)
                            .font(.caption)
                            .foregroundStyle(AppTheme.inkMuted)
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.inkFaint)
                        }
                    }
                }
            } else {
                Text("—")
                    .font(.callout)
                    .foregroundStyle(AppTheme.inkMuted)
            }
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("достижения за период")
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.inkFaint)
            if recap.achievementsUnlocked.isEmpty {
                Text("За этот период новых значков не было.")
                    .font(.callout)
                    .foregroundStyle(AppTheme.inkMuted)
            } else {
                ForEach(recap.achievementsUnlocked) { achievement in
                    HStack(spacing: 10) {
                        Image(systemName: "seal.fill")
                            .foregroundStyle(AppTheme.gold)
                        Text(AchievementService.title(for: achievement.kind))
                            .font(.callout)
                            .foregroundStyle(AppTheme.inkSoft)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(recapPanel)
    }

    private var monthlySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(VoiceContent.recapPhrase(.recapMonthlyTitle))
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppTheme.inkFaint)
            if recap.monthlyAddCount.allSatisfy({ $0.count == 0 }) {
                Text("Помесячно — тишина.")
                    .font(.callout)
                    .foregroundStyle(AppTheme.inkMuted)
            } else {
                Chart(recap.monthlyAddCount, id: \.month) { item in
                    BarMark(
                        x: .value("Месяц", monthLabel(item.month)),
                        y: .value("Добавлено", item.count)
                    )
                    .foregroundStyle(AppTheme.goldSoft.gradient)
                }
                .frame(height: 140)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(recapPanel)
    }

    private var shareButton: some View {
        Button {
            shareRecapPNG()
        } label: {
            Label("Поделиться сводкой", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.gold)
        .font(.system(size: 13, design: .monospaced))
        .padding(.bottom, 24)
    }

    private var recapPanel: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppTheme.panel)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.panelLine, lineWidth: 1))
    }

    private func monthLabel(_ month: Int) -> String {
        let symbols = Calendar.current.shortMonthSymbols
        guard month >= 1, month <= symbols.count else { return "\(month)" }
        return symbols[month - 1]
    }

    private func shareRecapPNG() {
        guard let url = SharePNGExporter.temporaryPNGURL(
            filename: "yearly-recap-\(recap.period.displayTitle)",
            width: 360,
            scale: 3,
            content: {
                YearlyRecapSharePoster(recap: recap, handle: handle)
            }
        ) else { return }
        sharePayload = SharePayload(items: [url])
    }
}

struct YearlyRecapSharePoster: View {
    let recap: YearlyRecap
    let handle: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 18) {
                Text(recap.period.displayTitle)
                    .font(.system(size: 28, design: .serif).weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                Text("\(recap.totalRecords)")
                    .font(.system(size: 64, design: .serif).weight(.bold))
                    .foregroundStyle(AppTheme.gold)

                Text("пластинок за период")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppTheme.inkFaint)

                if !recap.topGenres.isEmpty {
                    posterColumn(title: "жанры", lines: recap.topGenres.map { "\($0.name) · \($0.count)" })
                }
                if !recap.topArtists.isEmpty {
                    posterColumn(title: "артисты", lines: recap.topArtists.map { "\($0.name) · \($0.count)" })
                }
                if !recap.topLabels.isEmpty {
                    posterColumn(title: "лейблы", lines: recap.topLabels.map { "\($0.name) · \($0.count)" })
                }

                if !recap.decadeDistribution.isEmpty {
                    HStack(alignment: .bottom, spacing: 6) {
                        let maxVal = recap.decadeDistribution.map(\.count).max() ?? 1
                        ForEach(recap.decadeDistribution, id: \.decade) { item in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppTheme.goldSoft)
                                    .frame(width: 14, height: CGFloat(item.count) / CGFloat(max(1, maxVal)) * 48)
                                Text("\(item.decade)")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(AppTheme.inkFaint)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(alignment: .trailing, spacing: 6) {
                if !handle.isEmpty {
                    Text(handle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.inkFaint)
                }
                SpeedMark45_33(showText: true)
            }
            .padding(20)
        }
        .frame(width: 360, height: 450)
        .background(AppTheme.bg)
    }

    private func posterColumn(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(AppTheme.inkFaint)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(AppTheme.inkSoft)
            }
        }
    }
}
