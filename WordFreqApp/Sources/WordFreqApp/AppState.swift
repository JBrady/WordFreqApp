import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var selectedFileURL: URL?
    @Published var options = AnalysisOptions()
    @Published var results: [WordCount] = []
    @Published var resultsStale = true
    @Published var searchText = ""
    @Published var statusMessage = "Choose a .txt play file and click Analyze."
    @Published var additionalStopwordsText = ""
    @Published var builtInStopwords: [String] = []
    
    @Published var debugLoadedChars: Int = 0
    @Published var debugTokenCount: Int = 0
    @Published var debugBuiltInIgnoredCount: Int = 0
    @Published var debugAdditionalIgnoredCount: Int = 0
    @Published var debugMergedIgnoredCount: Int = 0
    @Published var previewCompact: String = ""
    @Published var previewFull: String = ""
    @Published var debugPreview: String = ""
    @Published var debugSampleTokens: [String] = []
    @Published var isAnalyzing = false

    private var builtInStopwordsSet: Set<String> = []
    private var analyzeTask: Task<Void, Never>?
    private var activeAnalyzeRunID: UUID?

    nonisolated static let topNRange = 1...5000
    nonisolated static let minLengthRange = 1...20
    nonisolated static let maxFileBytes = 20 * 1024 * 1024
    nonisolated private static let compactLinesCap = 10
    nonisolated private static let fullLinesCap = 26
    nonisolated private static let compactCharCap = 4_000
    nonisolated private static let fullCharCap = 12_000

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
        cancelAnalysisIfRunning()

        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.plainText, UTType.text]

        if panel.runModal() == .OK, let url = panel.url {
            cancelAnalysisIfRunning()
            clearPreviewAndDebugData()

            if let oversizedMessage = oversizedFileMessage(for: url) {
                selectedFileURL = nil
                invalidateResults(statusMessageOverride: oversizedMessage)
                return
            }

            do {
                let text = try withSecurityScopedAccess(to: url) {
                    try TextLoader.loadText(at: url)
                }
                selectedFileURL = url
                applyPreviewData(Self.buildPreviewData(from: text))
                refreshDebugStopwordCounts()
                invalidateResults()
            } catch {
                cancelAnalysisIfRunning()
                selectedFileURL = nil
                clearPreviewAndDebugData()
                invalidateResults(statusMessageOverride: friendlyLoadErrorMessage(for: error))
            }
        }
    }

    func analyze() {
        guard let fileURL = selectedFileURL else {
            statusMessage = "Please choose a .txt file first."
            return
        }

        if let oversizedMessage = oversizedFileMessage(for: fileURL) {
            cancelAnalysisIfRunning()
            selectedFileURL = nil
            clearPreviewAndDebugData()
            invalidateResults(statusMessageOverride: oversizedMessage)
            return
        }

        cancelAnalysisIfRunning()
        isAnalyzing = true
        statusMessage = "Analyzing…"

        let runID = UUID()
        activeAnalyzeRunID = runID
        let options = clampedOptions
        let builtInStopwordsSet = builtInStopwordsSet
        let additionalStopwordsText = additionalStopwordsText

        analyzeTask = Task.detached(priority: .userInitiated) { [fileURL] in
            do {
                let text = try Self.loadTextWithSecurityAccess(from: fileURL)
                try Task.checkCancellation()

                let previewData = Self.buildPreviewData(from: text)

                // Tokenize the same way Analyzer does
                let normalized = Normalizer.normalize(text)
                let tokenizerOptions = TokenizerOptions(
                    keepInternalApostrophes: options.keepInternalApostrophes,
                    includeNumbers: options.includeNumbers,
                    allowNonLatinLetters: options.allowNonLatinLetters
                )
                let tokens = Tokenizer.tokenize(normalized, options: tokenizerOptions)

                // Stopwords / ignored words
                let stopwords = Stopwords.merged(
                    builtIn: builtInStopwordsSet,
                    additionalRawText: additionalStopwordsText
                )
                let additionalStopwords = Stopwords.parse(rawText: additionalStopwordsText)
                let results = Analyzer.analyze(text: text, stopwords: stopwords, options: options)
                let warning = Self.nonLatinWarning(for: text, allowNonLatin: options.allowNonLatinLetters)

                try Task.checkCancellation()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard !Task.isCancelled, self.activeAnalyzeRunID == runID else { return }
                    self.applyPreviewData(previewData)
                    self.debugTokenCount = tokens.count
                    self.debugSampleTokens = Array(tokens.prefix(30))
                    self.debugBuiltInIgnoredCount = builtInStopwordsSet.count
                    self.debugAdditionalIgnoredCount = additionalStopwords.count
                    self.debugMergedIgnoredCount = stopwords.count
                    self.results = results
                    self.resultsStale = false
                    self.isAnalyzing = false
                    self.analyzeTask = nil
                    self.activeAnalyzeRunID = nil

                    let resultLabel = options.includeNumbers ? "words and numbers" : "words"
                    if let warning {
                        self.statusMessage = "Analysis complete. Found \(results.count) \(resultLabel). \(warning)"
                    } else {
                        self.statusMessage = "Analysis complete. Found \(results.count) \(resultLabel)."
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    guard self.activeAnalyzeRunID == runID else { return }
                    self.cancelAnalysisIfRunning()
                }
            } catch {
                await MainActor.run {
                    guard self.activeAnalyzeRunID == runID else { return }
                    self.cancelAnalysisIfRunning()
                    self.clearPreviewAndDebugData()
                    self.results = []
                    self.resultsStale = true
                    self.statusMessage = self.friendlyLoadErrorMessage(for: error)
                }
            }
        }
    }

    func exportCSV() {
        guard !results.isEmpty, !resultsStale else {
            statusMessage = "No results to export."
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "word-frequency.csv"
        panel.allowedContentTypes = [UTType.commaSeparatedText]

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try withSecurityScopedAccess(to: url) {
                    try CSVExporter.write(rows: filteredResults, to: url)
                }
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

    func invalidateResults(reason _: String? = nil) {
        cancelAnalysisIfRunning()
        results = []
        resultsStale = true
        statusMessage = "Press Analyze to update results."
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
            builtInStopwords = Stopwords.builtInWords
            debugBuiltInIgnoredCount = builtInStopwordsSet.count
        } catch {
            builtInStopwordsSet = []
            builtInStopwords = []
            statusMessage = "Could not load bundled stopwords: \(error.localizedDescription)"
        }
    }

    private func invalidateResults(statusMessageOverride: String) {
        cancelAnalysisIfRunning()
        results = []
        resultsStale = true
        statusMessage = statusMessageOverride
    }

    private func refreshDebugStopwordCounts() {
        debugBuiltInIgnoredCount = builtInStopwordsSet.count
        debugAdditionalIgnoredCount = Stopwords.parse(rawText: additionalStopwordsText).count
        debugMergedIgnoredCount = Stopwords.merged(
            builtIn: builtInStopwordsSet,
            additionalRawText: additionalStopwordsText
        ).count
    }

    private func clearPreviewAndDebugData() {
        debugLoadedChars = 0
        previewCompact = ""
        previewFull = ""
        debugPreview = ""
        debugTokenCount = 0
        debugSampleTokens = []
        refreshDebugStopwordCounts()
    }

    private func applyPreviewData(_ previewData: PreviewData) {
        debugLoadedChars = previewData.loadedChars
        previewCompact = previewData.compact
        previewFull = previewData.full
        debugPreview = previewData.debug
    }

    func cancelAnalysisIfRunning() {
        analyzeTask?.cancel()
        analyzeTask = nil
        // Move run identifier forward so stale background work cannot publish.
        activeAnalyzeRunID = UUID()
        isAnalyzing = false
    }

    private func fileSizeInBytes(for url: URL) -> Int? {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            return values.fileSize
        } catch {
            return nil
        }
    }

    private func oversizedFileMessage(for url: URL) -> String? {
        guard let size = fileSizeInBytes(for: url) else {
            return nil
        }
        guard size > Self.maxFileBytes else {
            return nil
        }
        return Self.fileTooLargeMessage(fileSizeBytes: size)
    }

    nonisolated static func formatMB(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_048_576.0
        return String(format: "%.1f MB", mb)
    }

    nonisolated static func fileTooLargeMessage(fileSizeBytes: Int?, limitBytes: Int = AppState.maxFileBytes) -> String {
        guard let fileSizeBytes else {
            return "File is too large. WordFreq supports up to \(formatMB(limitBytes))."
        }
        return "File is \(formatMB(fileSizeBytes)). WordFreq supports up to \(formatMB(limitBytes))."
    }

    private func friendlyLoadErrorMessage(for error: Error) -> String {
        if let textLoaderError = error as? TextLoaderError,
           let description = textLoaderError.errorDescription {
            return description
        }
        return "Could not read the selected file. Please confirm it is a readable .txt file and try again."
    }

    private func withSecurityScopedAccess<T>(to url: URL, operation: () throws -> T) throws -> T {
        // Security-scoped access is only meaningful for file URLs (e.g., Open/Save panel or bookmark URLs).
        guard url.isFileURL else {
            return try operation()
        }
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    nonisolated private static func loadTextWithSecurityAccess(from url: URL) throws -> String {
        guard url.isFileURL else {
            return try TextLoader.loadText(at: url)
        }
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try TextLoader.loadText(at: url)
    }

    struct PreviewData {
        let compact: String
        let full: String
        let debug: String
        let loadedChars: Int
    }

    nonisolated static func buildPreviewData(from text: String) -> PreviewData {
        let compact = makePreview(
            from: text,
            linesCap: compactLinesCap,
            charCap: compactCharCap
        )
        let full = makePreview(
            from: text,
            linesCap: fullLinesCap,
            charCap: fullCharCap
        )
        return PreviewData(
            compact: compact,
            full: full,
            debug: String(text.prefix(300)),
            loadedChars: text.count
        )
    }

    nonisolated private static func makePreview(from text: String, linesCap: Int, charCap: Int) -> String {
        guard linesCap > 0, charCap > 0 else { return "" }

        // Fast path for pathological single-line files to avoid unnecessary splitting.
        guard text.contains("\n") else {
            return String(text.prefix(charCap))
        }

        let segments = text.split(
            separator: "\n",
            maxSplits: max(0, linesCap - 1),
            omittingEmptySubsequences: false
        )
        let joined = segments.joined(separator: "\n")
        guard joined.count > charCap else { return joined }
        return String(joined.prefix(charCap))
    }

    nonisolated private static func nonLatinWarning(for text: String, allowNonLatin: Bool) -> String? {
        guard !allowNonLatin else { return nil }

        let sample = text.prefix(1200)
        var totalLetters = 0
        var nonLatinLetters = 0

        for scalar in sample.unicodeScalars {
            guard scalar.properties.isAlphabetic else { continue }
            totalLetters += 1
            if !isLatinLetter(scalar) {
                nonLatinLetters += 1
            }
        }

        guard totalLetters >= 30 else { return nil }
        let nonLatinRatio = Double(nonLatinLetters) / Double(totalLetters)
        guard nonLatinRatio >= 0.70 else { return nil }

        return "Warning: text preview appears mostly non-Latin while \"Allow non-Latin letters\" is off. Verify file encoding/content."
    }

    nonisolated private static func isLatinLetter(_ scalar: UnicodeScalar) -> Bool {
        let value = scalar.value
        return (0x0041...0x007A).contains(value)
            || (0x00C0...0x00FF).contains(value)
            || (0x0100...0x017F).contains(value)
            || (0x0180...0x024F).contains(value)
            || (0x1E00...0x1EFF).contains(value)
            || (0x2C60...0x2C7F).contains(value)
            || (0xA720...0xA7FF).contains(value)
            || (0xAB30...0xAB6F).contains(value)
    }
}
