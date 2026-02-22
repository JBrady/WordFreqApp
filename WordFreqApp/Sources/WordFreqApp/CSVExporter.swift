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
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
