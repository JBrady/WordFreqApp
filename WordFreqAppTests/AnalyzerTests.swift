import XCTest
@testable import WordFreqApp

final class AnalyzerTests: XCTestCase {
    func testBasicCountingRemovesStopwords() {
        let text = """
        apple apple apple
        banana banana
        orange
        the the the
        """

        let stopwords: Set<String> = ["the"]
        let result = analyzeToMap(text: text, stopwords: stopwords)

        XCTAssertEqual(result["apple"], 3)
        XCTAssertEqual(result["banana"], 2)
        XCTAssertEqual(result["orange"], 1)
        XCTAssertNil(result["the"], "Stopword 'the' should not appear in analyzed output")
    }

    func testCaseNormalization() {
        let text = """
        Apple apple APPLE
        Banana BANANA
        """

        let result = analyzeToMap(text: text)

        XCTAssertEqual(result["apple"], 3)
        XCTAssertEqual(result["banana"], 2)
        XCTAssertEqual(result.keys.filter { $0.lowercased() == "apple" }.count, 1)
        XCTAssertEqual(result.keys.filter { $0.lowercased() == "banana" }.count, 1)
    }

    func testPunctuationHandling() {
        let text = "hello, hello. hello! world? world"

        let result = analyzeToMap(text: text)

        XCTAssertEqual(result["hello"], 3)
        XCTAssertEqual(result["world"], 2)
        XCTAssertTrue(result.keys.allSatisfy { !$0.contains(",") && !$0.contains(".") && !$0.contains("!") && !$0.contains("?") })
    }

    func testApostropheBehaviorWhenKeepingInternalApostrophes() {
        let text = "don't don't dont"
        var options = AnalysisOptions()
        options.keepInternalApostrophes = true

        let result = analyzeToMap(text: text, options: options)

        XCTAssertEqual(result["don't"], 2)
        XCTAssertEqual(result["dont"], 1)
    }

    func testApostropheBehaviorWhenDroppingApostrophes() {
        let text = "don't don't dont"
        var options = AnalysisOptions()
        options.keepInternalApostrophes = false

        let result = analyzeToMap(text: text, options: options)

        XCTAssertEqual(result["dont"], 3)
        XCTAssertNil(result["don't"])
    }

    func testStopwordMerging() {
        let builtInRaw = """
        the
        and
        of
        """
        let builtIn = Stopwords.parse(rawText: builtInRaw)

        let additionalRaw = """
        hamlet
        ophelia
        # comment line
        """

        let merged = Stopwords.merged(builtIn: builtIn, additionalRawText: additionalRaw)

        XCTAssertTrue(merged.contains("the"))
        XCTAssertTrue(merged.contains("and"))
        XCTAssertTrue(merged.contains("of"))
        XCTAssertTrue(merged.contains("hamlet"))
        XCTAssertTrue(merged.contains("ophelia"))
        XCTAssertEqual(merged.count, 5)
    }

    func testTopNEnforcementWithManyUniqueWords() {
        let uniqueWords = (0..<250).map { "word\($0)" }
        let text = uniqueWords.joined(separator: " ")

        var options = AnalysisOptions()
        options.includeNumbers = true
        options.topN = 100

        let top100 = Analyzer.analyze(text: text, stopwords: [], options: options)
        XCTAssertEqual(top100.count, 100)

        options.topN = 300
        let top300 = Analyzer.analyze(text: text, stopwords: [], options: options)
        XCTAssertEqual(top300.count, 250)
    }

    func testTokenizerProducesRealisticCountForResumeLikeText() {
        let sentence = "Experienced software engineer delivering reliable macOS tools, SwiftUI apps, API integrations, and measurable product impact."
        let text = Array(repeating: sentence, count: 30).joined(separator: " ")

        let normalized = Normalizer.normalize(text)
        let tokens = Tokenizer.tokenize(
            normalized,
            options: TokenizerOptions(
                keepInternalApostrophes: false,
                includeNumbers: false,
                allowNonLatinLetters: false
            )
        )

        XCTAssertGreaterThan(tokens.count, 250)
    }

    func testCJKFilteringWithAllowNonLatinToggle() {
        let text = "hello 你好 hello"
        let normalized = Normalizer.normalize(text)

        let latinOnlyTokens = Tokenizer.tokenize(
            normalized,
            options: TokenizerOptions(
                keepInternalApostrophes: false,
                includeNumbers: false,
                allowNonLatinLetters: false
            )
        )
        XCTAssertEqual(latinOnlyTokens.filter { $0 == "hello" }.count, 2)
        XCTAssertFalse(latinOnlyTokens.contains("你好"))

        let allScriptTokens = Tokenizer.tokenize(
            normalized,
            options: TokenizerOptions(
                keepInternalApostrophes: false,
                includeNumbers: false,
                allowNonLatinLetters: true
            )
        )
        XCTAssertEqual(allScriptTokens.filter { $0 == "hello" }.count, 2)
        XCTAssertTrue(allScriptTokens.contains("你好"))
    }

    func testBuiltInStopwordsLoadFromBundle() throws {
        let builtIn = try Stopwords.loadBuiltIn(bundle: .main)
        XCTAssertGreaterThan(builtIn.count, 0)
        XCTAssertTrue(builtIn.contains("the"))
    }

    private func analyzeToMap(
        text: String,
        stopwords: Set<String> = [],
        options: AnalysisOptions = AnalysisOptions()
    ) -> [String: Int] {
        let rows = Analyzer.analyze(text: text, stopwords: stopwords, options: options)
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.word, $0.count) })
    }
}
