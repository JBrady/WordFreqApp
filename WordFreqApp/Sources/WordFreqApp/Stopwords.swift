import Foundation

enum StopwordsError: LocalizedError {
    case missingBuiltInList

    var errorDescription: String? {
        switch self {
        case .missingBuiltInList:
            return "Missing bundled stopwords list."
        }
    }
}

enum Stopwords {
    static func loadBuiltIn(bundle: Bundle = .main) throws -> Set<String> {
        guard let url = bundle.url(forResource: "stopwords_en", withExtension: "txt") else {
            throw StopwordsError.missingBuiltInList
        }
        return try load(from: url)
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

    private static func load(from url: URL) throws -> Set<String> {
        let raw = try TextLoader.loadText(at: url, requireTXTExtension: false)
        return parse(rawText: raw)
    }
}
