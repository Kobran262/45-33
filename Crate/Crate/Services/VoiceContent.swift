import Foundation

enum VoiceKey: String {
    case emptyShelfFirst
    case emptyWishlist
    case emptySearchResults
    case loadingDiscogs
    case errorNetworkDiscogs
    case errorGeneric
    case warnDuplicate
    case warnAmbiguousBarcode
    case confirmBulkDelete
    case suggestGenre
    case suggestArtist
    case suggestDecade
    case suggestRecent
    case suggestColored
    case vitrinaCaptionCollection
    case vitrinaCaptionRecord
    case importCSVProgress
    case importCSVSummary
}

@MainActor
enum VoiceContent {
    private static var lastIndexByKey: [VoiceKey: Int] = [:]

    static func phrase(_ key: VoiceKey) -> String {
        let values = phrases[key, default: []]
        guard !values.isEmpty else { return "" }
        guard values.count > 1 else { return values[0] }

        var index = Int.random(in: 0..<values.count)
        if index == lastIndexByKey[key] {
            index = (index + 1) % values.count
        }
        lastIndexByKey[key] = index
        return values[index]
    }

    static func phrase(_ key: VoiceKey, replacements: [String: String]) -> String {
        replacements.reduce(phrase(key)) { value, pair in
            value.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
        }
    }

    static func fact(for release: DiscogsRelease, fallbackResult: DiscogsSearchResult? = nil) -> String {
        pickFact(for: release, fallbackResult: fallbackResult)
    }

    /// v3: факт в ~60% добавлений; для первой пластинки — всегда.
    static func shouldShowFactWhenAdding(shelfCount: Int) -> Bool {
        if shelfCount == 0 { return true }
        return Int.random(in: 0..<10) < 6
    }

    static func milestoneBody(for kind: String) -> String {
        guard kind.hasPrefix("milestone"),
              let count = Int(kind.replacingOccurrences(of: "milestone", with: "")),
              let phrases = milestonePhrases[count], !phrases.isEmpty else {
            return "Юбилей на полке. Запомни этот момент."
        }
        return phrases.randomElement() ?? phrases[0]
    }

    static func achievementBody(for kind: String) -> String {
        if kind.hasPrefix("firstGenre.") {
            let tag = kind.replacingOccurrences(of: "firstGenre.", with: "")
            return phraseAchievement(.achievementFirstGenre, tag: tag)
        }
        if kind.hasPrefix("genre10.") {
            let tag = kind.replacingOccurrences(of: "genre10.", with: "")
            return phraseAchievement(.achievementGenre10, tag: tag)
        }
        if kind.hasPrefix("label5.") {
            let labelName = kind.replacingOccurrences(of: "label5.", with: "")
            return phraseAchievement(.achievementLabel5, label: labelName)
        }
        if kind == "fiveDecades" {
            return achievementPhrases[.achievementFiveDecades]?.randomElement()
                ?? "Пять эпох на одной полке. Кто-то тут серьёзно копает."
        }
        return milestoneBody(for: kind)
    }

    static func summaryTotalSpent(sum: String, amount: Double) -> String {
        let key: VoiceRecapKey
        if amount < 500 { key = .summarySpentLow }
        else if amount <= 1500 { key = .summarySpentMid }
        else { key = .summarySpentHigh }
        return recapPhrase(key).replacingOccurrences(of: "{SUM}", with: sum)
    }

    static func recapHero(count: Int) -> String {
        let key: VoiceRecapKey
        switch count {
        case 0: key = .recapHeroEmpty
        case 1...5: key = .recapHeroFew
        case 6...30: key = .recapHeroNormal
        default: key = .recapHeroHeavy
        }
        return recapPhrase(key)
            .replacingOccurrences(of: "{N}", with: "\(count)")
    }

    static func recapPhrase(_ key: VoiceRecapKey) -> String {
        let values = recapPhrases[key, default: []]
        guard !values.isEmpty else { return "" }
        return values.randomElement() ?? values[0]
    }

    private static func phraseAchievement(_ key: VoiceAchievementKey, tag: String = "", label: String = "") -> String {
        let values = achievementPhrases[key, default: []]
        guard !values.isEmpty else { return "" }
        let raw = values.randomElement() ?? values[0]
        return raw
            .replacingOccurrences(of: "{GENRE}", with: tag.capitalized)
            .replacingOccurrences(of: "{LABEL}", with: label.capitalized)
    }

    private struct FactCandidate {
        let text: String
        let id: String
        let weight: Int
    }

    private static let recentFactIDsKey = "recentFactIDs"

    private static func pickFact(for release: DiscogsRelease, fallbackResult: DiscogsSearchResult?) -> String {
        var pool: [FactCandidate] = []
        let artist = release.primaryArtist.lowercased()
        let title = release.title.components(separatedBy: " - ").last?.lowercased() ?? release.title.lowercased()

        if let matched = VoiceContentRecordFacts.all.first(where: { fact in
            artist.contains(fact.artist) && title.contains(fact.album)
        }) {
            for (index, text) in matched.texts.enumerated() {
                pool.append(FactCandidate(
                    text: text,
                    id: "record:\(matched.artist):\(matched.album):\(index)",
                    weight: 5
                ))
            }
        }

        let label = release.primaryLabel.lowercased()
        labelGroups(for: label).forEach { group in
            addGroupPhrases(group, weight: 3, to: &pool)
        }

        var genreParts: [String] = []
        genreParts.append(contentsOf: release.genres ?? [])
        genreParts.append(contentsOf: release.styles ?? [])
        genreParts.append(contentsOf: fallbackResult?.genre ?? [])
        genreParts.append(contentsOf: fallbackResult?.style ?? [])
        let genres = genreParts.joined(separator: " ").lowercased()
        genreGroups(for: genres).forEach { group in
            addGroupPhrases(group, weight: 2, to: &pool)
        }

        let year = release.year ?? fallbackResult?.yearInt ?? 0
        if let decadeGroup = decadeGroup(for: year) {
            addGroupPhrases(decadeGroup, weight: 2, to: &pool)
        }

        let format = release.formatDescription.lowercased()
        pressingGroups(for: format).forEach { group in
            addGroupPhrases(group, weight: 2, to: &pool)
        }

        let generic = factPhrases[.genericFact, default: []]
        for text in generic.shuffled().prefix(3) {
            pool.append(FactCandidate(text: text, id: factID(group: .genericFact, text: text), weight: 1))
        }

        if pool.isEmpty {
            addGroupPhrases(.genericFact, weight: 1, to: &pool)
        }

        return selectWeighted(from: pool)
    }

    private static func addGroupPhrases(_ group: FactGroup, weight: Int, to pool: inout [FactCandidate]) {
        for text in factPhrases[group, default: []] {
            pool.append(FactCandidate(text: text, id: factID(group: group, text: text), weight: weight))
        }
    }

    private static func factID(group: FactGroup, text: String) -> String {
        "\(group.rawValue):\(text.hashValue)"
    }

    private static func selectWeighted(from pool: [FactCandidate]) -> String {
        var recent = UserDefaults.standard.stringArray(forKey: recentFactIDsKey) ?? []
        var available = pool.filter { !recent.contains($0.id) }
        if available.isEmpty {
            recent = []
            UserDefaults.standard.set(recent, forKey: recentFactIDsKey)
            available = pool
        }

        let totalWeight = available.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0, let chosen = weightedPick(available, totalWeight: totalWeight) else {
            return pool.first?.text ?? ""
        }

        recent.insert(chosen.id, at: 0)
        if recent.count > 20 { recent = Array(recent.prefix(20)) }
        UserDefaults.standard.set(recent, forKey: recentFactIDsKey)
        return chosen.text
    }

    private static func weightedPick(_ pool: [FactCandidate], totalWeight: Int) -> FactCandidate? {
        var roll = Int.random(in: 0..<totalWeight)
        for candidate in pool {
            roll -= candidate.weight
            if roll < 0 { return candidate }
        }
        return pool.last
    }

    private static func labelGroups(for label: String) -> [FactGroup] {
        var groups: [FactGroup] = []
        if label.contains("blue note") { groups.append(.labelBlueNote) }
        if label.contains("ecm") { groups.append(.labelECM) }
        if label.contains("motown") { groups.append(.labelMotown) }
        if label.contains("stax") { groups.append(.labelStax) }
        if label.contains("atlantic") { groups.append(.labelAtlantic) }
        if label.contains("verve") { groups.append(.labelVerve) }
        if label.contains("columbia") { groups.append(.labelColumbia) }
        if label.contains("impulse") { groups.append(.labelImpulse) }
        if label.contains("riverside") { groups.append(.labelRiverside) }
        if label.contains("4ad") { groups.append(.label4AD) }
        if label.contains("factory") { groups.append(.labelFactory) }
        if label.contains("def jam") { groups.append(.labelDefJam) }
        if label.contains("sub pop") { groups.append(.labelSubPop) }
        if label.contains("apple") { groups.append(.labelApple) }
        return groups
    }

    private static func genreGroups(for genres: String) -> [FactGroup] {
        var groups: [FactGroup] = []
        if genres.contains("indie folk") || genres.contains("indie-folk") { groups.append(.genreIndieFolk) }
        if genres.contains("krautrock") || genres.contains("kraut") { groups.append(.genreKrautrock) }
        if genres.contains("experimental") || genres.contains("avant") { groups.append(.genreExperimental) }
        if genres.contains("world") || genres.contains("afrobeat") || genres.contains("latin") { groups.append(.genreWorld) }
        if genres.contains("ambient") || genres.contains("drone") { groups.append(.genreAmbient) }
        if genres.contains("reggae") || genres.contains("dub") || genres.contains("ska") { groups.append(.genreReggae) }
        if genres.contains("metal") || genres.contains("heavy") { groups.append(.genreMetal) }
        if genres.contains("blues") { groups.append(.genreBlues) }
        if genres.contains("country") || genres.contains("americana") { groups.append(.genreCountry) }
        if genres.contains("jazz") { groups.append(.genreJazz) }
        if genres.contains("classical") { groups.append(.genreClassical) }
        if genres.contains("electronic") || genres.contains("techno") || genres.contains("house") { groups.append(.genreElectronic) }
        if genres.contains("hip") || genres.contains("rap") { groups.append(.genreHipHop) }
        if genres.contains("funk") { groups.append(.genreFunk) }
        if genres.contains("soul") || genres.contains("r&b") || genres.contains("rnb") { groups.append(.genreSoul) }
        if genres.contains("folk") && !groups.contains(.genreIndieFolk) { groups.append(.genreIndieFolk) }
        if genres.contains("rock") || genres.contains("punk") || genres.contains("grunge") { groups.append(.genreRock) }
        return groups
    }

    private static func decadeGroup(for year: Int) -> FactGroup? {
        switch year {
        case 1950..<1960: return .decade1950
        case 1960..<1970: return .decade1960
        case 1970..<1980: return .decade1970
        case 1980..<1990: return .decade1980
        case 1990..<2000: return .decade1990
        case 2000...: return .decade2000
        default: return nil
        }
    }

    private static func pressingGroups(for format: String) -> [FactGroup] {
        var groups: [FactGroup] = []
        if format.contains("mono") { groups.append(.pressMono) }
        if format.contains("180") { groups.append(.press180g) }
        if format.contains("half-speed") || format.contains("half speed") { groups.append(.pressHalfSpeed) }
        if format.contains("japan") { groups.append(.pressJapanese) }
        if format.contains("colored") || format.contains("colour") || format.contains("red") || format.contains("clear") {
            groups.append(.pressColored)
        }
        if format.contains("first press") || format.contains("1st press") { groups.append(.pressFirst) }
        return groups
    }

    private static let phrases: [VoiceKey: [String]] = [
        .emptyShelfFirst: [
            "Каждая коллекция начинается с одной пластинки. Где-то она у тебя уже лежит — давай занесём.",
            "Здесь будет твоя полка. Пока пусто, но это поправимо.",
            "С чего-то надо начать. Обычно с самой любимой.",
            "Ноль пластинок. Лучшее время начать.",
            "Полка ждёт. Любую первую — даже ту, что ты стыдишься показывать.",
            "Чистый лист. Лучше, чем кажется.",
            "Пока пусто. Но мы тут не торопимся.",
            "Это твоё начало. Не сравнивай его с чужими полками.",
            "Первая пластинка где-то рядом — мы подождём.",
            "Сейчас тут только намерения. Скоро будут пластинки.",
            "Каждая большая коллекция начиналась с одной кривой стопки.",
            "Пусто, как у всех в первый день.",
            "Полка обновлена. То есть пуста, но красиво пуста.",
            "Запиши свою первую — потом будешь рад, что не забыл.",
            "Самое сложное в коллекционировании — начать вести учёт. Дальше пойдёт."
        ],
        .emptyWishlist: [
            "Вишлист пуст. Подозрительно — у всех есть та самая пластинка, которую жаба не даёт купить.",
            "Пока ничего не хочется? Не верим.",
            "Здесь живёт список охоты. Закинь хотя бы одну — для разгона.",
            "Чистый вишлист. Либо у тебя всё есть, либо ты что-то скрываешь.",
            "Вишлист пуст. Самый редкий вид коллекционера — без хотелок.",
            "Ни одной мечты. Это либо просветление, либо лень.",
            "Пусто. А ведь где-то прямо сейчас выставляют ту самую пластинку.",
            "Здесь будет список того, за чем охотишься. Пока он короткий — ноль.",
            "Тихо. Ни одной хотелки. Так не бывает, но допустим.",
            "Вишлист ждёт первую пластинку. Любую, с которой жаба воюет.",
            "Пусто, и это удивительно для коллекционера.",
            "Ни одной мечты пока не записано. Запиши хоть одну — облегчает охоту."
        ],
        .emptySearchResults: [
            "Discogs пожимает плечами. Попробуй другое написание?",
            "Ничего не нашлось. Бывает — особенно с редкими прессингами.",
            "Пусто. Может, опечатка в названии артиста?",
            "Не вижу такой пластинки. Внеси вручную, если знаешь, что ищешь.",
            "Discogs молчит. Иногда они переименовывают релизы — попробуй другое название.",
            "Ноль совпадений. Если уверен, что пластинка существует — добавь вручную.",
            "Не нашли. Проверь имя артиста — Discogs строгий к написанию.",
            "Пустой результат. Может, это редкий локальный прессинг — заведи руками.",
            "Ничего. Странно — но не страшно.",
            "Discogs не знает такой. Это не приговор — просто внеси сам.",
            "Не нашлось ни одного совпадения. Бывает, если артист совсем нишевый.",
            "Пусто. Если это редкое издание — Discogs мог его не индексировать."
        ],
        .loadingDiscogs: [
            "Discogs роется на полке…",
            "Ищем твою пластинку в большой базе…",
            "Сверяемся с Discogs…",
            "Минутку — крутим каталог.",
            "Discogs думает. У него миллион релизов в голове.",
            "Перебираем переиздания…",
            "Сверяемся с большой базой винила…",
            "Discogs шуршит страницами…",
            "Минутку — листаем каталог.",
            "Достаём данные из Discogs."
        ],
        .errorNetworkDiscogs: [
            "Discogs сейчас не берёт трубку. Попробуем ещё раз?",
            "Discogs молчит. Не страшно — попробуй чуть позже.",
            "Не достучались до Discogs. Сеть или их сервер — гадать не будем.",
            "Discogs занят. Попробуй через минуту."
        ],
        .errorGeneric: [
            "Что-то пошло не так. Попробуй ещё раз.",
            "Не получилось. Повтори, пожалуйста.",
            "Ошибка. Не страшная — повтори."
        ],
        .warnDuplicate: [
            "Похоже, эта уже на полке.",
            "Кажется, у тебя уже есть. Если это вторая копия — это нормально.",
            "Возможный дубль. Проверь?",
            "Дежа вю. Эта вроде у тебя уже была.",
            "Сверь — возможно, дубликат."
        ],
        .warnAmbiguousBarcode: [
            "Нашли {N} переизданий. Проверь, какое твоё.",
            "{N} вариантов прессинга. Уточни?",
            "Не уверены, какое именно — {N} совпадений.",
            "{N} версий этой пластинки. Какая из них у тебя?"
        ],
        .confirmBulkDelete: [
            "Снять с полки {N} пластинок? Это действие нельзя будет быстро откатить.",
            "{N} пластинок уйдут с полки. Проверь стопку перед тем, как нажать.",
            "Удаляем {N} записей из коллекции? Винил останется дома, но в приложении его больше не будет."
        ],
        .suggestGenre: [
            "{N} пластинок жанра «{GENRE}» — собрать в коллекцию?",
            "У тебя уже {N} пластинок «{GENRE}». Может, отдельная полка?",
            "{GENRE} набралось на {N} штук. Заведём коллекцию?",
            "{GENRE} прёт. Собрать в одну коллекцию?",
            "{N} пластинок «{GENRE}». Это уже не случайность."
        ],
        .suggestArtist: [
            "{N} пластинок {ARTIST}. Собираешь дискографию?",
            "{ARTIST} — уже {N} релизов на полке. Сделать коллекцию артиста?",
            "{N} раз {ARTIST}. Заведём ему отдельную полку?",
            "{ARTIST} явно прижился. Собрать в коллекцию?"
        ],
        .suggestDecade: [
            "{N} пластинок {DECADE}. Эпоха явно зацепила — собрать вместе?",
            "{DECADE} набралось на {N} штук. Заведём коллекцию по эпохе?",
            "{DECADE} — твоё. {N} пластинок. Сделать полку эпохи?"
        ],
        .suggestRecent: [
            "{N} пластинок за последний месяц. Посмотреть как «Новинки»?",
            "За месяц прибыло {N}. Активный был месяц.",
            "{N} новых за месяц. Хорошая охота."
        ],
        .suggestColored: [
            "{N} цветных пластинок. Собрать «Цветной винил» отдельно?",
            "Цветного винила набралось на {N} штук. Заведём коллекцию?",
            "Цветные собираются — уже {N}. Сделать им отдельную полку?"
        ],
        .vitrinaCaptionCollection: [
            "Полка, собранная за {YEARS} лет",
            "Моё «{TAG}» — пока что",
            "Так выглядит моя {TAG}-полка сегодня",
            "{N} пластинок и одно увлечение",
            "Коллекция в процессе. Как всегда.",
            "Полка на сегодня. Завтра может измениться."
        ],
        .vitrinaCaptionRecord: [
            "Из той самой стопки",
            "Долго охотился",
            "Один из любимых конвертов",
            "Эта стоила того",
            "Не самая дорогая, но самая любимая",
            "Долгожданная",
            "Сегодня вертится у меня"
        ],
        .importCSVProgress: [
            "Импортируем стопку: {DONE} / {TOTAL}",
            "Переносим пластинки: {DONE} / {TOTAL}",
            "Разбираем CSV: {DONE} / {TOTAL}"
        ],
        .importCSVSummary: [
            "Импортировано: {IMPORTED}, пропущено как дубликаты: {SKIPPED}.",
            "Готово. На полке +{IMPORTED}, дублей не трогали: {SKIPPED}.",
            "CSV разобран: {IMPORTED} новых, {SKIPPED} уже были на полке."
        ]
    ]

    enum VoiceAchievementKey {
        case achievementFirstGenre
        case achievementGenre10
        case achievementLabel5
        case achievementFiveDecades
    }

    enum VoiceRecapKey {
        case recapHeroEmpty
        case recapHeroFew
        case recapHeroNormal
        case recapHeroHeavy
        case recapTopGenreIntro
        case recapTopArtistIntro
        case recapTopLabelIntro
        case recapMostExpensive
        case recapOldestPress
        case recapMonthlyTitle
        case summarySpentLow
        case summarySpentMid
        case summarySpentHigh
    }

    private static let achievementPhrases: [VoiceAchievementKey: [String]] = [
        .achievementFirstGenre: [
            "Первый след жанра «{GENRE}» на полке. Начало ветки.",
            "Жанр «{GENRE}» зашёл. Посмотрим, приживётся ли.",
            "«{GENRE}» появился на полке. Пока одна пластинка — но это старт.",
            "Новый жанровый след: {GENRE}. Полка расширяется.",
        ],
        .achievementGenre10: [
            "Десять пластинок «{GENRE}». Жанр явно прижился.",
            "«{GENRE}» — уже не эксперимент, а привычка.",
            "10 штук «{GENRE}». Это уже отдельная история на полке.",
            "Жанр «{GENRE}» занял место. Десятая пластинка это подтвердила.",
        ],
        .achievementLabel5: [
            "Этот лейбл прижился — уже пятая на полке.",
            "Пять пластинок одного лейбла. Знакомый звук.",
            "Лейбл «{LABEL}» — уже не случайность.",
            "Пятая с одного лейбла. Кто-то явно копает в одном месте.",
        ],
        .achievementFiveDecades: [
            "Пять эпох на одной полке. Кто-то тут серьёзно копает.",
            "Пять десятилетий в одной коллекции. Временная линия сложилась.",
            "От 50-х до сегодня — полка пересекла пять эпох.",
            "Пять разных десятилетий. Полка стала музеем времени.",
        ],
    ]

    private static let recapPhrases: [VoiceRecapKey: [String]] = [
        .recapHeroEmpty: [
            "Тихий год. С полкой ничего не случилось.",
            "Ноль новых пластинок за период. Полка отдыхала.",
            "Пустой отрезок. Иногда так и надо.",
            "За этот период — тишина. Полка не менялась.",
        ],
        .recapHeroFew: [
            "Аккуратное начало. {N} пластинок за год — это уже что-то.",
            "{N} пластинок за период. Небольшой, но честный прирост.",
            "Немного, но осознанно: {N} за период.",
            "{N} новых — скромно, зато каждая на счету.",
        ],
        .recapHeroNormal: [
            "{N} пластинок прижились за год. Полка заметно потяжелела.",
            "{N} за период — полка жила активной жизнью.",
            "За период +{N}. Коллекция выросла ровно.",
            "{N} пластинок — год, который слышно на полке.",
        ],
        .recapHeroHeavy: [
            "{N} пластинок за год — серьёзная охота.",
            "{N} за период. Полка явно не стояла на месте.",
            "Тяжёлый год для полки: {N} новых пластинок.",
            "{N} — это уже не хобби на выходных.",
        ],
        .recapTopGenreIntro: [
            "жанр года",
            "что чаще всего",
            "куда чаще возвращался",
        ],
        .recapTopArtistIntro: [
            "артист года",
            "к кому вернулся чаще всех",
            "чья пластинка звучала чаще",
        ],
        .recapTopLabelIntro: [
            "лейбл года",
            "чей звук чаще попадал на полку",
            "откуда чаще приезжали пластинки",
        ],
        .recapMostExpensive: [
            "самая дорогая покупка",
            "где жаба уступила сильнее всего",
            "самый дорогой след периода",
        ],
        .recapOldestPress: [
            "самая старая пластинка года",
            "самый дальний год издания",
            "самый старый прессинг за период",
        ],
        .recapMonthlyTitle: [
            "по месяцам",
            "когда тяжелее всего была полка",
            "когда добавлял чаще всего",
        ],
        .summarySpentLow: [
            "Вложено {SUM} — и это только начало.",
            "{SUM} — пока что бюджетно.",
            "{SUM} вложено. Всё впереди.",
        ],
        .summarySpentMid: [
            "Всего вложено: {SUM}.",
            "Сумма коллекции: {SUM}.",
            "Накоплено вложений: {SUM}.",
        ],
        .summarySpentHigh: [
            "Всего вложено: {SUM}.",
            "Стоимость коллекции по ценам покупки: {SUM}.",
            "За период в полку ушло: {SUM}.",
        ],
    ]
}
