import Foundation

enum CSVExporter {
    static func write(rows: [WordCount], to url: URL) throws {
        var lines = ["word,count"]
        lines.reserveCapacity(rows.count + 1)

        for row in rows {
            let escapedWord = escape(row.word)
            lines.append("\(escapedWord),\(row.count)")
        }

        let csv = lines.joined(separator: "\n")
        let data = Data(csv.utf8)
        try data.write(to: url, options: .atomic)
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
