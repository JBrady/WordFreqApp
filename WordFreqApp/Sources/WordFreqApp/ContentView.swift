import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox("Input") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Button("Choose File…") {
                            appState.choosePlayFile()
                        }
                        Text(appState.selectedFilePath)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    HStack(spacing: 10) {
                        Button("Load Custom Stopwords…") {
                            appState.chooseCustomStopwordsFile()
                        }

                        Button("Clear") {
                            appState.clearCustomStopwords()
                        }
                        .disabled(appState.customStopwordsURL == nil)

                        Text(appState.customStopwordsPath)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Options") {
                HStack(spacing: 18) {
                    HStack {
                        Text("Top N")
                        Stepper(value: $appState.options.topN, in: 1...50_000) {
                            Text("\(appState.options.topN)")
                                .monospacedDigit()
                                .frame(width: 70, alignment: .trailing)
                        }
                    }

                    HStack {
                        Text("Min Length")
                        Stepper(value: $appState.options.minWordLength, in: 1...30) {
                            Text("\(appState.options.minWordLength)")
                                .monospacedDigit()
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                }

                Toggle("Keep internal apostrophes", isOn: $appState.options.keepInternalApostrophes)
                Toggle("Include numbers", isOn: $appState.options.includeNumbers)
            }

            HStack(spacing: 10) {
                Button("Analyze") {
                    appState.analyze()
                }
                .keyboardShortcut(.return)
                .disabled(appState.selectedFileURL == nil)

                Button("Export CSV") {
                    appState.exportCSV()
                }
                .disabled(appState.results.isEmpty)

                Spacer()

                TextField("Filter words", text: $appState.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
            }

            Table(appState.filteredResults) {
                TableColumn("Word", value: \.word)
                    .width(min: 220)

                TableColumn("Count") { row in
                    Text("\(row.count)")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 100, max: 120)
            }
            .frame(minHeight: 360)

            Text(appState.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 640)
    }
}
