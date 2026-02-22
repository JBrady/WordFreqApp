import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var selectedFileURL: URL?
    @Published var options = AnalysisOptions()
    @Published var results: [WordCount] = []
    @Published var searchText = ""
    @Published var statusMessage = "Choose a .txt play file and click Analyze."
    @Published var additionalStopwordsText = ""
    @Published var builtInStopwords: [String] = []
    
    @Published var debugLoadedChars: Int = 0
    @Published var debugTokenCount: Int = 0
    @Published var debugBuiltInIgnoredCount: Int = 0
    @Published var debugAdditionalIgnoredCount: Int = 0
    @Published var debugMergedIgnoredCount: Int = 0
    @Published var debugPreview: String = ""
    @Published var debugSampleTokens: [String] = []

    private var builtInStopwordsSet: Set<String> = []

    static let topNRange = 1...5000
    static let minLengthRange = 1...20

    var selectedFilePath: String {
        selectedFileURL?.path ?? "No file selected"
    }

    var filteredResults: [WordCount] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return results
        }

        let query = searchText.lowercased()
        return results.filter { $0.word.contains(query) }
    }

    var bundledStopwordsCount: Int {
        builtInStopwords.count
    }

    init() {
        loadBundledStopwords()
    }

    func choosePlayFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.plainText, UTType.text]

        if panel.runModal() == .OK, let url = panel.url {
            selectedFileURL = url
            statusMessage = "Selected: \(url.lastPathComponent)"
        }
    }

    func analyze() {
        guard let selectedFileURL else {
            statusMessage = "Please choose a .txt file first."
            return
        }

        do {
            let text = try TextLoader.loadText(at: selectedFileURL)

            // DEBUG: how much text did we load?
            debugLoadedChars = text.count
            debugPreview = String(text.prefix(300))

            // Tokenize the same way Analyzer does
            let normalized = Normalizer.normalize(text)
            let tokenizerOptions = TokenizerOptions(
                keepInternalApostrophes: clampedOptions.keepInternalApostrophes,
                includeNumbers: clampedOptions.includeNumbers,
                allowNonLatinLetters: clampedOptions.allowNonLatinLetters
            )
            let tokens = Tokenizer.tokenize(normalized, options: tokenizerOptions)
            debugTokenCount = tokens.count
            debugSampleTokens = Array(tokens.prefix(30))

            // Stopwords / ignored words
            let stopwords = Stopwords.merged(
                builtIn: builtInStopwordsSet,
                additionalRawText: additionalStopwordsText
            )
            debugBuiltInIgnoredCount = builtInStopwordsSet.count
            debugAdditionalIgnoredCount = Stopwords.parse(rawText: additionalStopwordsText).count
            debugMergedIgnoredCount = stopwords.count

            results = Analyzer.analyze(text: text, stopwords: stopwords, options: clampedOptions)
            statusMessage = "Analysis complete. Found \(results.count) words."
        } catch {
            results = []
            statusMessage = error.localizedDescription

            debugLoadedChars = 0
            debugTokenCount = 0
            debugBuiltInIgnoredCount = builtInStopwordsSet.count
            debugAdditionalIgnoredCount = 0
            debugMergedIgnoredCount = 0
            debugPreview = ""
            debugSampleTokens = []
        }
    }

    func reanalyzeIfPossible() {
        guard selectedFileURL != nil else { return }
        analyze()
    }

    func exportCSV() {
        guard !results.isEmpty else {
            statusMessage = "No results to export."
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "word-frequency.csv"
        panel.allowedContentTypes = [UTType.commaSeparatedText]

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try CSVExporter.write(rows: filteredResults, to: url)
                statusMessage = "Exported CSV to \(url.lastPathComponent)."
            } catch {
                statusMessage = "CSV export failed: \(error.localizedDescription)"
            }
        }
    }

    func setTopN(_ value: Int) {
        options.topN = value.clamped(to: Self.topNRange)
    }

    func setMinWordLength(_ value: Int) {
        options.minWordLength = value.clamped(to: Self.minLengthRange)
    }

    var clampedOptions: AnalysisOptions {
        var copy = options
        copy.topN = copy.topN.clamped(to: Self.topNRange)
        copy.minWordLength = copy.minWordLength.clamped(to: Self.minLengthRange)
        return copy
    }

    private func loadBundledStopwords() {
        do {
            builtInStopwordsSet = try Stopwords.loadBuiltIn()
            builtInStopwords = builtInStopwordsSet.sorted()
        } catch {
            builtInStopwordsSet = []
            builtInStopwords = []
            statusMessage = "Could not load bundled stopwords: \(error.localizedDescription)"
        }
    }
}
