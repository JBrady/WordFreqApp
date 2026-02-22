import Foundation

enum Stopwords {
    static let builtInWords: [String] = [
        "the", "a", "an", "of", "to", "at", "in", "out", "and", "or", "but"
    ]

    private static let builtInSet = Set(builtInWords)

    static func loadBuiltIn(bundle: Bundle = .main) throws -> Set<String> {
        _ = bundle
        return builtInSet
    }

    static func parse(rawText: String) -> Set<String> {
        Set(
            rawText
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        )
    }

    static func merged(builtIn: Set<String>, additionalRawText: String) -> Set<String> {
        var all = builtIn
        all.formUnion(parse(rawText: additionalRawText))
        return all
    }

    static func merged(additionalRawText: String, bundle: Bundle = .main) throws -> Set<String> {
        let builtIn = try loadBuiltIn(bundle: bundle)
        return merged(builtIn: builtIn, additionalRawText: additionalRawText)
    }
}
