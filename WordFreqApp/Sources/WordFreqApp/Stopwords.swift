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

    static func loadCustom(from url: URL) throws -> Set<String> {
        try load(from: url)
    }

    static func merged(customURL: URL?) throws -> Set<String> {
        var all = try loadBuiltIn()
        if let customURL {
            all.formUnion(try loadCustom(from: customURL))
        }
        return all
    }

    private static func load(from url: URL) throws -> Set<String> {
        let raw = try TextLoader.loadText(at: url, requireTXTExtension: false)
        return Set(
            raw
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        )
    }
}
