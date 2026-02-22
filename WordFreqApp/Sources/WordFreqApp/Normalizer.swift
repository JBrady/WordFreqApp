import Foundation

enum Normalizer {
    static func normalize(_ text: String) -> String {
        var normalized = text.precomposedStringWithCompatibilityMapping.lowercased()

        let replacements: [String: String] = [
            "\u{2018}": "'",
            "\u{2019}": "'",
            "\u{02BC}": "'",
            "\u{201A}": "'",
            "\u{201B}": "'",
            "\u{201C}": "\"",
            "\u{201D}": "\"",
            "\u{201E}": "\"",
            "\u{201F}": "\""
        ]

        for (source, destination) in replacements {
            normalized = normalized.replacingOccurrences(of: source, with: destination)
        }

        return normalized
    }
}
