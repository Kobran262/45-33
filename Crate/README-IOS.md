# Crate · iOS

Нативное приложение «коллекция винила» на SwiftUI + SwiftData.
Дизайн — «Аналоговый стол»: тёмные тёплые тона, шрифты Serif/Mono, золотой акцент.

## Стек

| Слой                | Технология |
| ------------------- | ---------- |
| UI                  | SwiftUI (iOS 17+) |
| Хранение            | SwiftData (`@Model`) |
| Discogs             | URLSession `actor`, Personal Access Token |
| Карта               | MapKit + Overpass API (OpenStreetMap) |
| Локация             | CoreLocation (`CLLocationManager`) |
| Фото                | PhotosUI (`PhotosPicker`) + UIImagePickerController (камера) |
| Штрихкод            | AVFoundation (`AVCaptureMetadataOutput`) |
| Шаринг              | `ImageRenderer` + `UIActivityViewController` |

Никаких CocoaPods/SPM-зависимостей — только Apple-фреймворки.

## Открыть в Xcode

Проект уже сгенерирован через XcodeGen:

```bash
open /Users/admin/Downloads/винил/Crate/Crate.xcodeproj
```

Если правил `project.yml` — перегенерируй:

```bash
cd /Users/admin/Downloads/винил/Crate
xcodegen generate
```

В Xcode выбери симулятор iPhone 15 / 16 и нажми ▶ Run.

## Структура

```
Crate/
├── project.yml                     ← XcodeGen
├── Crate.xcodeproj                 ← сгенерированный проект
├── Resources/
│   ├── Info.plist                  ← permissions
│   ├── Secrets.plist               ← !!! не коммитить
│   ├── Crate.entitlements
│   └── Assets.xcassets/
└── Crate/                          ← исходники
    ├── App/CrateVinylApp.swift
    ├── Config/AppSecrets.swift
    ├── Models/
    │   ├── VinylRecord.swift
    │   ├── WishlistEntry.swift
    │   ├── SavedCollection.swift
    │   └── UserProfile.swift
    ├── Services/
    │   ├── Discogs/
    │   │   ├── DiscogsModels.swift
    │   │   ├── DiscogsService.swift
    │   │   └── DiscogsBarcodeSearch.swift
    │   ├── Map/
    │   │   ├── OverpassService.swift
    │   │   └── LocationService.swift
    │   └── SuggestionsEngine.swift
    └── Views/
        ├── ContentView.swift        TabView
        ├── ShelfView.swift          Полка
        ├── AddSingleView.swift      Добавить (поиск + барскан)
        ├── AddBatchView.swift       Стопка (массовый барскан)
        ├── RecordDetailView.swift   Карточка + PhotosPicker/камера
        ├── EditRecordView.swift     Редактирование полей
        ├── WishlistView.swift       Вишлист
        ├── ShowcaseView.swift       Витрина
        ├── ShowcaseRecordView.swift Карточка-шаринг
        ├── ProfileView.swift        Профиль + статы
        ├── Map/VinylShopsMapView.swift
        └── Components/
            ├── RecordCover.swift
            ├── BarcodeScannerView.swift  AVFoundation
            └── Theme.swift               Аналоговый стол
```

## Discogs API

Токен лежит в `Resources/Secrets.plist` — этот файл уже в `.gitignore`.

```xml
<key>DISCOGS_TOKEN</key>
<string>XAxDbIKCiwGnwuJVNUBFDGPdSNAwXTBiXbSGqRia</string>
```

> ⚠️ Этот токен **уже засветился в чате** — заходи на https://www.discogs.com/settings/developers, выпускай новый и заменяй значение в `Secrets.plist`. Старый отзови.

API доступен через `DiscogsService.shared`:
- `searchReleases(query:)` — поиск по тексту
- `searchByBarcode(_:)` — поиск по UPC/EAN
- `fetchRelease(id:)` — детальная информация
- `mapToRecord(_:)` — конвертация в `VinylRecord`

User-Agent выставлен в `AppSecrets.discogsUserAgent` — поменяй на свой GitHub-handle.

## Permissions

Все Usage Descriptions уже прописаны в `Info.plist`:

| Ключ                                       | Назначение |
| ------------------------------------------ | ---------- |
| `NSCameraUsageDescription`                 | барскан + фото обложки |
| `NSPhotoLibraryUsageDescription`           | выбрать обложку из галереи |
| `NSPhotoLibraryAddUsageDescription`        | сохранить готовую витрину |
| `NSLocationWhenInUseUsageDescription`      | карта магазинов |

## Что уже работает

- ✅ SwiftData-модели: `VinylRecord`, `WishlistEntry`, `SavedCollection`, `UserProfile`
- ✅ Полка с фильтрами, поиском и переходом в карточку
- ✅ Добавление пластинки: поиск в Discogs + ручное создание
- ✅ Сканер штрихкодов (AVFoundation) → поиск по UPC в Discogs
- ✅ Массовый барскан «стопка пластинок»
- ✅ Фото пластинки: галерея (`PhotosPicker`) и камера (`UIImagePickerController`)
- ✅ Витрина (карточка релиза + карточка коллекции) с `ImageRenderer` и шарингом
- ✅ Вишлист с переносом «в коллекцию»
- ✅ Профиль со статистикой и редактированием
- ✅ Карта `MapKit` + поиск магазинов через Overpass API
- ✅ Тема «Аналоговый стол» с золотыми чипами и фетровыми панелями

## Известные нюансы

- Discogs Personal Access Token в `Secrets.plist` подходит для прототипа и личного использования. Для App Store замени на свой OAuth-флоу или backend-прокси.
- Overpass API — публичный и иногда медленный/недоступный. Я добавил два endpoint'а с фолбэком.
- `ImageRenderer` для шаринга использует SwiftUI-рендер — на iOS 17 работает стабильно.

## Следующие шаги (если захочется)

1. Кастомные коллекции через UI (сейчас движок `SuggestionsEngine` уже создан, осталось добавить экран).
2. Импорт/экспорт JSON на iOS — через `FileDocument` и `.fileExporter`.
3. iCloud-синхронизация SwiftData через CloudKit (`ModelConfiguration(cloudKitDatabase: .automatic)`).
4. Виджет «последняя пластинка» через WidgetKit.
