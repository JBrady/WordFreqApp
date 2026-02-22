import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var selectedFileURL: URL?
    @Published var customStopwordsURL: URL?
    @Published var options = AnalysisOptions()
    @Published var results: [WordCount] = []
    @Published var searchText = ""
    @Published var statusMessage = "Choose a .txt play file and click Analyze."

    var selectedFilePath: String {
        selectedFileURL?.path ?? "No file selected"
    }

    var customStopwordsPath: String {
        customStopwordsURL?.path ?? "None"
    }

    var filteredResults: [WordCount] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return results
        }

        let query = searchText.lowercased()
        return results.filter { $0.word.contains(query) }
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

    func chooseCustomStopwordsFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.plainText, UTType.text]

        if panel.runModal() == .OK, let url = panel.url {
            customStopwordsURL = url
            statusMessage = "Custom stopwords loaded: \(url.lastPathComponent)"
        }
    }

    func clearCustomStopwords() {
        customStopwordsURL = nil
        statusMessage = "Custom stopwords cleared."
    }

    func analyze() {
        guard let selectedFileURL else {
            statusMessage = "Please choose a .txt file first."
            return
        }

        do {
            let text = try TextLoader.loadText(at: selectedFileURL)
            let stopwords = try Stopwords.merged(customURL: customStopwordsURL)
            results = Analyzer.analyze(text: text, stopwords: stopwords, options: options)
            statusMessage = "Analysis complete. Found \(results.count) words."
        } catch {
            results = []
            statusMessage = error.localizedDescription
        }
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
}
