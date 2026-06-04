import Foundation

enum RecapPeriod: Equatable, Hashable {
    case year(Int)
    case rolling12Months

    var displayTitle: String {
        switch self {
        case .year(let y): return "Год в виниле · \(y)"
        case .rolling12Months: return "Последние 12 месяцев"
        }
    }

    var isAvailable: Bool {
        let currentYear = Calendar.current.component(.year, from: .now)
        switch self {
        case .year(let y): return y < currentYear
        case .rolling12Months: return true
        }
    }

    func contains(date: Date, now: Date = .now) -> Bool {
        let calendar = Calendar.current
        switch self {
        case .year(let y):
            return calendar.component(.year, from: date) == y
        case .rolling12Months:
            guard let start = calendar.date(byAdding: .month, value: -12, to: now) else { return false }
            return date >= start && date <= now
        }
    }
}

struct YearlyRecap {
    let period: RecapPeriod
    let totalRecords: Int
    let totalSpent: Double
    let currency: String
    let topGenres: [(name: String, count: Int)]
    let topLabels: [(name: String, count: Int)]
    let topArtists: [(name: String, count: Int)]
    let decadeDistribution: [(decade: Int, count: Int)]
    let mostExpensive: VinylRecord?
    let oldestPress: VinylRecord?
    let firstAdded: VinylRecord?
    let lastAdded: VinylRecord?
    let achievementsUnlocked: [Achievement]
    let monthlyAddCount: [(month: Int, count: Int)]
}

enum YearlyRecapService {
    static func availablePeriods(from records: [VinylRecord], now: Date = .now) -> [RecapPeriod] {
        var periods: [RecapPeriod] = [.rolling12Months]
        let years = Set(records.map { Calendar.current.component(.year, from: $0.addedAt) })
            .sorted(by: >)
        for year in years {
            let p = RecapPeriod.year(year)
            if p.isAvailable { periods.append(p) }
        }
        return periods
    }

    static func defaultPeriod(from records: [VinylRecord], now: Date = .now) -> RecapPeriod {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        if month == 12 {
            let previous = RecapPeriod.year(year - 1)
            if previous.isAvailable,
               records.contains(where: { previous.contains(date: $0.addedAt, now: now) }) {
                return previous
            }
            if calendar.component(.day, from: now) >= 25 {
                return .year(year)
            }
        }
        return .rolling12Months
    }

    static func generate(
        period: RecapPeriod,
        records: [VinylRecord],
        achievements: [Achievement],
        now: Date = .now
    ) -> YearlyRecap {
        let filtered = records.filter { period.contains(date: $0.addedAt, now: now) }
            .sorted { $0.addedAt < $1.addedAt }

        let totalSpent = filtered.reduce(0) { $0 + $1.price }
        let currency = filtered.first?.currency ?? records.first?.currency ?? "€"

        let topGenres = topCounts(in: filtered.flatMap(\.tags), limit: 3)
        let topLabels = topCounts(
            in: filtered.map(\.label).filter { !$0.isEmpty && $0 != "—" },
            limit: 3
        )
        let topArtists = topCounts(in: filtered.map(\.artist), limit: 3)

        var decadeMap: [Int: Int] = [:]
        for record in filtered where record.year > 0 {
            let decade = (record.year / 10) * 10
            decadeMap[decade, default: 0] += 1
        }
        let decadeDistribution = decadeMap.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }

        let mostExpensive = filtered.max(by: { $0.price < $1.price })
        let oldestPress = filtered.filter { $0.year > 0 }.min(by: { $0.year < $1.year })
        let firstAdded = filtered.first
        let lastAdded = filtered.last

        let achievementsUnlocked = achievements.filter { period.contains(date: $0.unlockedAt, now: now) }

        let monthlyAddCount = monthlyBuckets(for: filtered, period: period, now: now)

        return YearlyRecap(
            period: period,
            totalRecords: filtered.count,
            totalSpent: totalSpent,
            currency: currency,
            topGenres: topGenres,
            topLabels: topLabels,
            topArtists: topArtists,
            decadeDistribution: decadeDistribution,
            mostExpensive: mostExpensive,
            oldestPress: oldestPress,
            firstAdded: firstAdded,
            lastAdded: lastAdded,
            achievementsUnlocked: achievementsUnlocked,
            monthlyAddCount: monthlyAddCount
        )
    }

    private static func normalizedKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func topCounts(in values: [String], limit: Int) -> [(name: String, count: Int)] {
        var counts: [String: (display: String, count: Int)] = [:]
        for value in values {
            let key = normalizedKey(value)
            guard !key.isEmpty else { continue }
            if var entry = counts[key] {
                entry.count += 1
                counts[key] = entry
            } else {
                counts[key] = (display: value.trimmingCharacters(in: .whitespacesAndNewlines), count: 1)
            }
        }
        return counts.values
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { ($0.display, $0.count) }
    }

    private static func monthlyBuckets(
        for records: [VinylRecord],
        period: RecapPeriod,
        now: Date
    ) -> [(month: Int, count: Int)] {
        let calendar = Calendar.current
        switch period {
        case .year(let y):
            var counts = Array(repeating: 0, count: 12)
            for record in records {
                guard calendar.component(.year, from: record.addedAt) == y else { continue }
                let month = calendar.component(.month, from: record.addedAt) - 1
                if month >= 0, month < 12 { counts[month] += 1 }
            }
            return counts.enumerated().map { ($0.offset + 1, $0.element) }
        case .rolling12Months:
            guard let start = calendar.date(byAdding: .month, value: -11, to: now) else {
                return (1...12).map { ($0, 0) }
            }
            var buckets: [(Date, Int)] = []
            for offset in 0..<12 {
                if let monthStart = calendar.date(byAdding: .month, value: offset, to: start) {
                    buckets.append((monthStart, 0))
                }
            }
            for record in records {
                guard let bucketIndex = buckets.firstIndex(where: { pair in
                    calendar.isDate(record.addedAt, equalTo: pair.0, toGranularity: .month)
                }) else { continue }
                buckets[bucketIndex].1 += 1
            }
            return buckets.enumerated().map { ($0.offset + 1, $0.element.1) }
        }
    }
}
