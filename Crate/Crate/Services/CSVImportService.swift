import Foundation

struct CSVImportDraft: Codable, Identifiable {
    var id: UUID = UUID()
    var artist: String
    var title: String
    var label: String
    var format: String
    var released: Int?
    var notes: String
    var folder: String
    var collectionNotes: String

    var story: String {
        [notes, collectionNotes]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    var tags: [String] {
        folder
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct CSVImportPreview: Codable {
    var totalRows: Int
    var validRows: Int
}

enum CSVImportService {
    static func parseDiscogsExport(data: Data) throws -> [CSVImportDraft] {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252) else {
            return []
        }

        let rows = parseCSV(text)
        guard let header = rows.first else { return [] }
        let normalizedHeader = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return rows.dropFirst().compactMap { row in
            let values = Dictionary(uniqueKeysWithValues: normalizedHeader.enumerated().map { index, key in
                (key, index < row.count ? row[index] : "")
            })
            let artist = values["Artist", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            let title = values["Title", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !artist.isEmpty, !title.isEmpty else { return nil }

            return CSVImportDraft(
                artist: artist,
                title: title,
                label: values["Label", default: ""],
                format: values["Format", default: ""],
                released: Int(values["Released", default: ""].prefix(4)),
                notes: values["Notes", default: ""],
                folder: values["Collection Folder", default: ""],
                collectionNotes: values["Collection Notes", default: ""]
            )
        }
    }

    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var iterator = text.makeIterator()

        while let character = iterator.next() {
            switch character {
            case "\"":
                if isQuoted {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append(next)
                        } else {
                            isQuoted = false
                            if next == "," {
                                row.append(field)
                                field = ""
                            } else if next == "\n" {
                                row.append(field)
                                rows.append(row)
                                row = []
                                field = ""
                            } else if next != "\r" {
                                field.append(next)
                            }
                        }
                    } else {
                        isQuoted = false
                    }
                } else if field.isEmpty {
                    isQuoted = true
                } else {
                    field.append(character)
                }
            case "," where !isQuoted:
                row.append(field)
                field = ""
            case "\n" where !isQuoted:
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            case "\r" where !isQuoted:
                continue
            default:
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }
}
