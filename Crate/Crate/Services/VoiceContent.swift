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
        let artist = release.primaryArtist.lowercased()
        let title = release.title.components(separatedBy: " - ").last?.lowercased() ?? release.title.lowercased()

        if let matched = recordFacts.first(where: { fact in
            artist.contains(fact.artist.lowercased()) && title.contains(fact.album.lowercased())
        }) {
            return matched.text
        }

        let label = release.primaryLabel.lowercased()
        if label.contains("blue note") { return phraseText(.labelBlueNote) }
        if label.contains("ecm") { return phraseText(.labelECM) }
        if label.contains("motown") { return phraseText(.labelMotown) }
        if label.contains("stax") { return phraseText(.labelStax) }
        if label.contains("atlantic") { return phraseText(.labelAtlantic) }
        if label.contains("verve") { return phraseText(.labelVerve) }
        if label.contains("columbia") { return phraseText(.labelColumbia) }
        if label.contains("impulse") { return phraseText(.labelImpulse) }

        var genreParts: [String] = []
        genreParts.append(contentsOf: release.genres ?? [])
        genreParts.append(contentsOf: release.styles ?? [])
        genreParts.append(contentsOf: fallbackResult?.genre ?? [])
        genreParts.append(contentsOf: fallbackResult?.style ?? [])
        let genres = genreParts.joined(separator: " ").lowercased()
        if genres.contains("jazz") { return phraseText(.genreJazz) }
        if genres.contains("rock") { return phraseText(.genreRock) }
        if genres.contains("classical") { return phraseText(.genreClassical) }
        if genres.contains("electronic") { return phraseText(.genreElectronic) }
        if genres.contains("hip") { return phraseText(.genreHipHop) }
        if genres.contains("funk") { return phraseText(.genreFunk) }
        if genres.contains("soul") { return phraseText(.genreSoul) }

        let format = release.formatDescription.lowercased()
        if format.contains("mono") { return phraseText(.pressMono) }
        if format.contains("180") { return phraseText(.press180g) }
        if format.contains("half-speed") || format.contains("half speed") { return phraseText(.pressHalfSpeed) }

        let year = release.year ?? fallbackResult?.yearInt ?? 0
        switch year {
        case 1950..<1960: return phraseText(.decade1950)
        case 1960..<1970: return phraseText(.decade1960)
        case 1970..<1980: return phraseText(.decade1970)
        case 1980..<1990: return phraseText(.decade1980)
        case 1990..<2000: return phraseText(.decade1990)
        case 2000...: return phraseText(.decade2000)
        default: return phraseText(.genericFact)
        }
    }

    private static func phraseText(_ group: FactGroup) -> String {
        let values = factPhrases[group, default: factPhrases[.genericFact, default: []]]
        guard !values.isEmpty else { return "" }
        return values.randomElement() ?? values[0]
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

    private enum FactGroup {
        case genericFact
        case decade1950
        case decade1960
        case decade1970
        case decade1980
        case decade1990
        case decade2000
        case labelBlueNote
        case labelECM
        case labelMotown
        case labelStax
        case labelAtlantic
        case labelVerve
        case labelColumbia
        case labelImpulse
        case genreJazz
        case genreRock
        case genreClassical
        case genreElectronic
        case genreHipHop
        case genreFunk
        case genreSoul
        case pressMono
        case press180g
        case pressHalfSpeed
    }

    private static let factPhrases: [FactGroup: [String]] = [
        .genericFact: [
            "А знаешь — это одна из тех пластинок, которые становятся лучше с возрастом.",
            "Эта вертится у людей десятилетиями. Видимо, не зря.",
            "Если эта попала к тебе — у тебя хороший вкус.",
            "Эта пластинка пережила пять поколений виниловых проигрывателей.",
            "Эту берут осознанно — случайно она в коллекцию не попадает."
        ],
        .decade1950: [
            "Пятидесятые. Винил тогда был не форматом, а единственным способом.",
            "Эпоха mono. Если попался стерео — значит, переиздание.",
            "50-е. Эра рождения LP-формата — раньше были только 78-е."
        ],
        .decade1960: [
            "Шестидесятые. Лучшее десятилетие винила, если спросить старших.",
            "Эпоха, когда обложки стали важны не меньше музыки.",
            "60-е. Тогда альбом перестал быть сборником синглов и стал высказыванием."
        ],
        .decade1970: [
            "Семидесятые. Тяжёлые конверты, толстый винил, серьёзные лица.",
            "Эпоха «концептуальных альбомов» — слушать надо целиком.",
            "В 70-х появились первые «аудиофильские» прессинги. Многие из них живы до сих пор."
        ],
        .decade1980: [
            "Восьмидесятые. Винил уже знал, что скоро придёт CD, и старался напоследок.",
            "80-е — последнее десятилетие, когда винил был основным форматом.",
            "Сейчас за этими прессингами идёт охота — их выпускали меньше, чем 70-е."
        ],
        .decade1990: [
            "Девяностые на виниле — редкость. Многое тогда выходило только на CD.",
            "Винил в 90-х был для верных. Тех, кто не сдался под натиском CD.",
            "Эпоха, когда виниловые тиражи были маленькими — что хорошо для редкости."
        ],
        .decade2000: [
            "Современный прессинг. 180 грамм, скорее всего — тяжелее старых.",
            "Реиссью часто звучат не хуже оригиналов. Иногда — лучше.",
            "Эта пластинка — часть «винилового ренессанса». Спасибо хипстерам."
        ],
        .labelBlueNote: [
            "Blue Note. Самый узнаваемый лейбл в джазе.",
            "Blue Note. Это уже не «лейбл», это часть джазовой ДНК.",
            "Обложки Рида Майлза. До сих пор копируют."
        ],
        .labelECM: [
            "ECM. «The most beautiful sound next to silence» — так у них на бумаге написано.",
            "Лейбл, который сделал тишину частью музыки.",
            "ECM. Манфред Айхер пишет звук так, будто записывает воздух между нотами."
        ],
        .labelMotown: [
            "Motown. Главная фабрика поп-музыки шестидесятых.",
            "Motown — про танец. Это слышно с первой секунды."
        ],
        .labelStax: [
            "Stax. Memphis Sound — грязнее и горячее, чем Motown.",
            "Stax записывал не глянец, а правду."
        ],
        .labelAtlantic: [
            "Atlantic. Лейбл, который умел делать всё — джаз, соул, рок, ритм-н-блюз.",
            "Atlantic — один из немногих лейблов, переживший всё."
        ],
        .labelVerve: [
            "Verve. Создан, чтобы записывать Элу Фитцджеральд так, как она того заслуживала.",
            "Verve — главный конкурент Blue Note. Только звук теплее и глянцевее."
        ],
        .labelColumbia: [
            "Columbia. Один из старейших лейблов в мире — основан в 1888 году.",
            "Columbia первой массово начала выпускать LP-формат в 1948 году."
        ],
        .labelImpulse: [
            "Impulse! Лейбл, на котором Coltrane выпускал свои самые смелые вещи.",
            "Оранжево-чёрные конверты Impulse — узнаваемые с любого расстояния."
        ],
        .genreJazz: [
            "Джаз на виниле — это, кажется, единственный честный способ его слушать.",
            "Джаз был придуман для аналогового звука. На цифре он немного теряет."
        ],
        .genreRock: [
            "Классика жанра. Эту до сих пор переиздают каждые пару лет.",
            "Рок-альбомы делали для виниловых сторон по 20 минут — отсюда и структура."
        ],
        .genreClassical: [
            "Классика на виниле — отдельная религия. С аудиофилами не спорь.",
            "Классика и джаз — два жанра, которые продали винил аудиофилам."
        ],
        .genreElectronic: [
            "Электроника на виниле — отдельный мир. Тут даже промахи звучат красиво.",
            "Винил для электроники — носитель для диджеев. Многие треки изначально делались под него."
        ],
        .genreHipHop: [
            "Хип-хоп вырос из винила. Без поворотников и баттлов диджеев его бы не было.",
            "Сэмплы в хип-хопе — это, по сути, кусочки чужих пластинок. Эта могла стать одним из них."
        ],
        .genreFunk: [
            "Фанк. Если бы у винила был жанр-родитель, был бы фанк.",
            "Тяжёлый бас на этих пластинках — отдельный аттракцион."
        ],
        .genreSoul: [
            "Соул. Голос важнее всего, и винил эту тёплость не съедает.",
            "Соул на виниле звучит так, как должен — мягко и в лицо."
        ],
        .pressMono: [
            "Mono-прессинг. Многие считают, что джаз и блюз надо слушать только так.",
            "Mono — это не «хуже стерео», это другой звук. Запомни."
        ],
        .press180g: [
            "180 грамм. Тяжёлый винил — стандарт современных переизданий.",
            "180g не делает звук автоматически лучше — но снижает резонансы."
        ],
        .pressHalfSpeed: [
            "Half-speed master. Запись делалась на пониженной скорости — это даёт больше деталей.",
            "Half-speed — премиальная техника мастеринга. Не на каждой пластинке."
        ]
    ]

    private struct RecordFact {
        let artist: String
        let album: String
        let text: String
    }

    private static let recordFacts: [RecordFact] = [
        .init(artist: "miles davis", album: "kind of blue", text: "Записан за две сессии. Почти всё с первого дубля. Считается самой продаваемой джазовой пластинкой в истории."),
        .init(artist: "john coltrane", album: "a love supreme", text: "Coltrane подал это как духовное приношение. Записал с классическим квартетом за одну сессию."),
        .init(artist: "pink floyd", album: "the dark side of the moon", text: "Альбом, который продаётся непрерывно с 1973 года. Концепт про время, безумие, деньги."),
        .init(artist: "joy division", album: "unknown pleasures", text: "Обложка с пульсаром — самый растиражированный графический мотив в музыке."),
        .init(artist: "radiohead", album: "ok computer", text: "Альбом про будущее, написанный в 1997 году. Сейчас он звучит ещё актуальнее."),
        .init(artist: "nirvana", album: "nevermind", text: "Альбом, который убил глэм-метал и принёс гранж в мейнстрим."),
        .init(artist: "amy winehouse", album: "back to black", text: "Соул в современной упаковке. Винехаус не успела дожить до зрелости — это её зенит.")
    ]
}
