# Crate — модель приложения (v2)

Рабочий прототип в `index.html`. Исходники логики: `src/01-models.js` … `src/05-app.js`.  
Сборка: `python3 build.py`

## Архитектура

```
UI (CrateUI)          ← рендер, навигация, модалки
    ↓ читает/пишет
Store (CrateStore)    ← единый state + localStorage
    ↓ использует
Models (CrateModels)  ← Record, WishlistItem, Collection…
Services              ← Catalog, Stats, Suggestions, Photos
```

## Сущности (→ Swift struct)

### Record
| Поле | Тип | Описание |
|------|-----|----------|
| id | string | UUID |
| title | string | Название альбома |
| artist | string | Исполнитель |
| year | number | Год |
| color | string | Hex обложки (fallback) |
| photo | string? | Base64 JPEG |
| vinylColor | string | black, clear, red, gold, marble, splatter |
| grade | string | VG, VG+, NM, M |
| price | number | Сумма покупки |
| currency | string | € |
| pressing | string | |
| label | string | |
| tags | string[] | Теги / жанр |
| favorite | boolean | |
| story | string | История (приватно) |
| addedAt | number | timestamp |

### WishlistItem
`id`, `title`, `artist`, `year?`, `note`, `addedAt`

### SavedCollection
Коллекция = сохранённый фильтр (не папка с копиями).

| type | value пример |
|------|----------------|
| tag | недавние |
| genre | джаз |
| artist | Miles Davis |
| decade | 1970 |
| favorite | — |

### Profile
`name`, `handle`, `since`, `avatar`, `premium`, `defaultShowcaseStyle`

## Store API (→ Repository)

- `load()` / `save()`
- `getRecords()`, `addRecord()`, `updateRecord()`, `deleteRecord()`
- `filterRecords(filter)` — all, jazz, rock, fav, col:{id}
- `getWishlist()`, `addWishlist()`, `moveWishlistToShelf()`
- `addCollection()`, `recordsForCollection()`
- `getBatchDraft()`, `commitBatch()`
- `exportJson()` / `importJson()`

## Services (→ Use Cases)

| Сервис | Назначение |
|--------|------------|
| Catalog | Поиск по демо-каталогу (замена Discogs) |
| Stats | Вложено, десятилетия, сводка коллекции |
| Suggestions | 5 типов автопредложений (жанр, артист, десятилетие, недавние, цвет винила) |
| Photos | Сжатие и привязка фото к Record |

## Навигация

Hash-router: `#/shelf`, `#/record/{id}`, `#/wishlist`, `#/add-single`, …

## MVP-покрытие

| Фича | Статус |
|------|--------|
| Каталог + поиск (демо) | ✅ |
| Добавление по одной / списком | ✅ |
| Ручное добавление | ✅ |
| Трекинг затрат | ✅ |
| Вишлист | ✅ |
| Теги и сохранённые коллекции | ✅ |
| Витрина пластинки / коллекции | ✅ |
| Фото офлайн | ✅ |
| Автопредложения (5 типов) | ✅ |
| Экспорт / импорт JSON | ✅ |
| Карта сторов | UI (пост-MVP данные) |
| Реальный Discogs API | 🔜 нужен ключ + сеть |
| Облако / синхронизация | 🔜 |

## iOS (SwiftUI)

Рекомендуемая структура:

```
Models/Record.swift, WishlistItem.swift, SavedCollection.swift
Store/AppStore.swift          @ObservableObject
Services/CatalogService.swift
Views/ShelfView.swift, RecordDetailView.swift, …
```

`Record` и `SavedCollection` — Codable, персистенция через SwiftData или JSON в FileManager (аналог localStorage).
