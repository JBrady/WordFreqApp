import Foundation

struct WordCount: Identifiable, Hashable {
    let word: String
    let count: Int

    var id: String { word }
}

struct AnalysisOptions {
    var topN: Int = 100
    var minWordLength: Int = 2
    var keepInternalApostrophes: Bool = false
    var includeNumbers: Bool = false
    var allowNonLatinLetters: Bool = false
}

enum Analyzer {
    static func analyze(text: String, stopwords: Set<String>, options: AnalysisOptions) -> [WordCount] {
        let normalized = Normalizer.normalize(text)
        let tokenizerOptions = TokenizerOptions(
            keepInternalApostrophes: options.keepInternalApostrophes,
            includeNumbers: options.includeNumbers,
            allowNonLatinLetters: options.allowNonLatinLetters
        )

        let tokens = Tokenizer.tokenize(normalized, options: tokenizerOptions)
        var counts: [String: Int] = [:]
        counts.reserveCapacity(tokens.count / 2)

        for token in tokens {
            guard token.count >= options.minWordLength else { continue }
            guard !stopwords.contains(token) else { continue }
            counts[token, default: 0] += 1
        }

        return counts
            .map { WordCount(word: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count {
                    return $0.word < $1.word
                }
                return $0.count > $1.count
            }
            .prefix(max(options.topN, 0))
            .map { $0 }
    }
}
