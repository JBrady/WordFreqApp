import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showLoadedPreview = false
    @State private var showTokenSample = false
    @State private var didConfigureWindow = false

    private var topNBinding: Binding<Int> {
        Binding(
            get: { appState.options.topN },
            set: {
                appState.setTopN($0)
                appState.reanalyzeIfPossible()
            }
        )
    }

    private var minWordLengthBinding: Binding<Int> {
        Binding(
            get: { appState.options.minWordLength },
            set: {
                appState.setMinWordLength($0)
                appState.reanalyzeIfPossible()
            }
        )
    }

    var body: some View {
        ScrollView(.vertical) {
            // Keep the root adaptive and scrollable so expanded sections are always reachable.
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

                    DisclosureGroup("Loaded Text Preview", isExpanded: $showLoadedPreview) {
                        ScrollView {
                            Text(appState.debugPreview.isEmpty ? "No text loaded yet." : appState.debugPreview)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(maxHeight: 170)
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Options") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 18) {
                        NumericStepperField(
                            title: "Top N",
                            value: topNBinding,
                            range: AppState.topNRange,
                            fieldWidth: 86
                        )

                        NumericStepperField(
                            title: "Min Length",
                            value: minWordLengthBinding,
                            range: AppState.minLengthRange,
                            fieldWidth: 56
                        )
                    }

                    Toggle("Keep internal apostrophes", isOn: $appState.options.keepInternalApostrophes)
                        .onChange(of: appState.options.keepInternalApostrophes) { _ in
                            appState.reanalyzeIfPossible()
                        }

                    Toggle("Include numbers", isOn: $appState.options.includeNumbers)
                        .onChange(of: appState.options.includeNumbers) { _ in
                            appState.reanalyzeIfPossible()
                        }

                    Toggle("Allow non-Latin letters", isOn: $appState.options.allowNonLatinLetters)
                        .onChange(of: appState.options.allowNonLatinLetters) { _ in
                            appState.reanalyzeIfPossible()
                        }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Automatically ignored words: \(appState.builtInStopwords.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Additional Words to Ignore (one per line)")
                    .font(.subheadline)

                TextEditor(text: $appState.additionalStopwordsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 110, maxHeight: 130)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    }
                    .onChange(of: appState.additionalStopwordsText) { _ in
                        appState.reanalyzeIfPossible()
                    }

                Text("Lines are trimmed, lowercased, and merged with default ignored words. Empty lines and lines starting with # are ignored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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

                VStack(alignment: .leading, spacing: 2) {
                    TextField("Filter Results (display only)", text: $appState.searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                    Text("Does not affect analysis")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("Loaded \(appState.debugLoadedChars) chars | Tokens \(appState.debugTokenCount) | Ignored \(appState.debugBuiltInIgnoredCount) built-in + \(appState.debugAdditionalIgnoredCount) additional = \(appState.debugMergedIgnoredCount)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            DisclosureGroup("Tokenizer Sample Tokens", isExpanded: $showTokenSample) {
                ScrollView {
                    Text(appState.debugSampleTokens.isEmpty ? "No tokens captured yet." : appState.debugSampleTokens.joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 180)
                .background(Color(NSColor.textBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                }
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
            .frame(minHeight: 320, idealHeight: 380, maxHeight: 420)

            Text(appState.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: configureWindowIfNeeded)
    }

    private func configureWindowIfNeeded() {
        guard !didConfigureWindow else { return }

        DispatchQueue.main.async {
            guard !didConfigureWindow, let window = NSApp.windows.first else { return }

            didConfigureWindow = true
            let minimumSize = NSSize(width: 800, height: 650)
            let defaultSize = NSSize(width: 900, height: 750)
            window.minSize = minimumSize

            let currentSize = window.frame.size
            if currentSize.width < defaultSize.width || currentSize.height < defaultSize.height {
                window.setContentSize(defaultSize)
            }
        }
    }
}

private struct NumericStepperField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let fieldWidth: CGFloat

    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Text(title)

            TextField(title, text: $text)
                .frame(width: fieldWidth)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .onSubmit(commitText)
                .onChange(of: text) { newValue in
                    applyTextInput(newValue)
                }

            Stepper("", value: $value, in: range)
                .labelsHidden()
        }
        .onAppear {
            text = "\(value.clamped(to: range))"
        }
        .onChange(of: value) { newValue in
            let clamped = newValue.clamped(to: range)
            if clamped != value {
                value = clamped
                return
            }
            let formatted = "\(clamped)"
            if text != formatted {
                text = formatted
            }
        }
    }

    private func applyTextInput(_ candidate: String) {
        let digitsOnly = candidate.filter(\.isNumber)
        if digitsOnly != candidate {
            text = digitsOnly
            return
        }

        guard !digitsOnly.isEmpty else { return }
        guard let parsed = Int(digitsOnly) else { return }

        let clamped = parsed.clamped(to: range)
        if value != clamped {
            value = clamped
        }
        if digitsOnly != "\(clamped)" {
            text = "\(clamped)"
        }
    }

    private func commitText() {
        guard !text.isEmpty, let parsed = Int(text) else {
            value = range.lowerBound
            text = "\(range.lowerBound)"
            return
        }

        let clamped = parsed.clamped(to: range)
        value = clamped
        text = "\(clamped)"
    }
}
