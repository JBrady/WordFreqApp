import AppKit
import SwiftUI

private enum ActionFocus: Hashable {
    case chooseFile
    case analyze
    case export
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    @State private var didConfigureWindow = false
    @State private var showExportToast = false
    @State private var showDebugSheet = false
    @State private var showFullPreview = false
    @FocusState private var focusedAction: ActionFocus?

    private let autoIgnoredInlineText = "Automatically ignored words: the, a, an, of, to, at, in, out, and, or, but"

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
        ZStack {
            AppTheme.pageGradient(for: colorScheme)
                .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        HeaderBar()

                        if proxy.size.width >= 900 {
                            WideLayout(
                                appState: appState,
                                topNBinding: topNBinding,
                                minWordLengthBinding: minWordLengthBinding,
                                autoIgnoredInlineText: autoIgnoredInlineText,
                                showFullPreview: $showFullPreview,
                                focusedAction: $focusedAction
                            )
                        } else {
                            NarrowLayout(
                                appState: appState,
                                topNBinding: topNBinding,
                                minWordLengthBinding: minWordLengthBinding,
                                autoIgnoredInlineText: autoIgnoredInlineText,
                                showFullPreview: $showFullPreview,
                                focusedAction: $focusedAction
                            )
                        }
                    }
                    .padding(AppTheme.pagePadding)
                    .frame(minHeight: max(0, proxy.size.height - (AppTheme.pagePadding * 2)), alignment: .top)
                }
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.contentScrim(for: colorScheme))
                        .padding(12)
                }
            }

            if showExportToast {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ToastView(message: "CSV exported successfully")
                    }
                }
                .padding(.trailing, 22)
                .padding(.bottom, 22)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.28, dampingFraction: 0.88), value: showExportToast)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showDebugSheet = true
                } label: {
                    Label("Debug", systemImage: "ladybug")
                }
                .help("Show debug diagnostics")
            }
        }
        .sheet(isPresented: $showDebugSheet) {
            DebugView(appState: appState)
        }
        .onAppear(perform: configureWindowIfNeeded)
        .onChange(of: appState.statusMessage) { message in
            guard message.hasPrefix("Exported CSV to") else { return }
            showExportToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                showExportToast = false
            }
        }
    }

    private func configureWindowIfNeeded() {
        guard !didConfigureWindow else { return }

        DispatchQueue.main.async {
            guard !didConfigureWindow, let window = NSApp.windows.first else { return }

            didConfigureWindow = true
            let minimumSize = NSSize(width: 840, height: 680)
            let defaultSize = NSSize(width: 900, height: 750)
            window.minSize = minimumSize

            let currentSize = window.frame.size
            if currentSize.width < defaultSize.width || currentSize.height < defaultSize.height {
                window.setContentSize(defaultSize)
            }
        }
    }
}

private struct HeaderBar: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("WordFreq")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("word frequency analyzer")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

private struct WideLayout: View {
    @ObservedObject var appState: AppState
    let topNBinding: Binding<Int>
    let minWordLengthBinding: Binding<Int>
    let autoIgnoredInlineText: String
    @Binding var showFullPreview: Bool
    let focusedAction: FocusState<ActionFocus?>.Binding

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.paneGap) {
            VStack(alignment: .leading, spacing: 16) {
                LeftPane(
                    appState: appState,
                    showFullPreview: $showFullPreview,
                    focusedAction: focusedAction
                )

                OptionsCard(
                    appState: appState,
                    topNBinding: topNBinding,
                    minWordLengthBinding: minWordLengthBinding,
                    autoIgnoredInlineText: autoIgnoredInlineText,
                    focusedAction: focusedAction,
                    fillsHeight: true
                )
                .frame(maxHeight: .infinity)
            }
            .frame(minWidth: 360, idealWidth: 390, maxWidth: 440, maxHeight: .infinity, alignment: .top)

            ResultsCard(appState: appState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct NarrowLayout: View {
    @ObservedObject var appState: AppState
    let topNBinding: Binding<Int>
    let minWordLengthBinding: Binding<Int>
    let autoIgnoredInlineText: String
    @Binding var showFullPreview: Bool
    let focusedAction: FocusState<ActionFocus?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LeftPane(
                appState: appState,
                showFullPreview: $showFullPreview,
                focusedAction: focusedAction
            )

            ResultsCard(appState: appState)
                .frame(minHeight: 300, idealHeight: 380, maxHeight: 450)

            OptionsCard(
                appState: appState,
                topNBinding: topNBinding,
                minWordLengthBinding: minWordLengthBinding,
                autoIgnoredInlineText: autoIgnoredInlineText,
                focusedAction: focusedAction,
                fillsHeight: false
            )
        }
    }
}

private struct LeftPane: View {
    @ObservedObject var appState: AppState
    @Binding var showFullPreview: Bool
    let focusedAction: FocusState<ActionFocus?>.Binding

    private var previewHeight: CGFloat {
        showFullPreview ? 360 : 160
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("File & Preview")
                .font(.system(.title3, design: .rounded).weight(.bold))

            HStack(spacing: 10) {
                Button {
                    appState.choosePlayFile()
                } label: {
                    Text("Choose File…")
                }
                .buttonStyle(PrimaryButtonStyle(isFocused: focusedAction.wrappedValue == .chooseFile))
                .focusable(true)
                .focused(focusedAction, equals: .chooseFile)

                Text(appState.selectedFilePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Loaded Text Preview")
                        .font(.subheadline.weight(.semibold))

                    Spacer(minLength: 8)

                    Button(showFullPreview ? "Show compact preview" : "Show full preview") {
                        showFullPreview.toggle()
                    }
                    .buttonStyle(.link)
                    .font(.caption.weight(.semibold))
                    .disabled(appState.selectedFileURL == nil)
                }

                ScrollView(.vertical, showsIndicators: true) {
                    Text(appState.debugPreview.isEmpty ? "No text loaded yet." : appState.debugPreview)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(height: previewHeight)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .glassCardStyle()
    }
}

private struct OptionsCard: View {
    @ObservedObject var appState: AppState
    let topNBinding: Binding<Int>
    let minWordLengthBinding: Binding<Int>
    let autoIgnoredInlineText: String
    let focusedAction: FocusState<ActionFocus?>.Binding
    let fillsHeight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.system(.title3, design: .rounded).weight(.bold))

            HStack(spacing: 10) {
                Button("Analyze") {
                    appState.analyze()
                }
                .buttonStyle(PrimaryButtonStyle(isFocused: focusedAction.wrappedValue == .analyze))
                .focusable(true)
                .focused(focusedAction, equals: .analyze)
                .keyboardShortcut(.return)
                .disabled(appState.selectedFileURL == nil)

                Button("Export CSV") {
                    appState.exportCSV()
                }
                .buttonStyle(PrimaryButtonStyle(isFocused: focusedAction.wrappedValue == .export))
                .focusable(true)
                .focused(focusedAction, equals: .export)
                .disabled(appState.results.isEmpty)

                Spacer(minLength: 0)
            }

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
                    fieldWidth: 62
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

            VStack(alignment: .leading, spacing: 6) {
                Text("Filter Results")
                    .font(.subheadline.weight(.semibold))

                TextField("Filter visible words", text: $appState.searchText)
                    .textFieldStyle(.roundedBorder)

                Text("Filters visible results only (does not affect analysis).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(autoIgnoredInlineText)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Additional Words to Ignore (one per line)")
                    .font(.subheadline.weight(.semibold))

                TextEditor(text: $appState.additionalStopwordsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 90, maxHeight: 120)
                    .padding(4)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    }
                    .onChange(of: appState.additionalStopwordsText) { _ in
                        appState.reanalyzeIfPossible()
                    }

                Text("Lines are trimmed, lowercased, and merged with default ignored words. Empty lines and lines starting with # are ignored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if fillsHeight {
                Spacer(minLength: 0)
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .glassCardStyle()
    }
}

private struct ResultsCard: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.system(.title3, design: .rounded).weight(.bold))

            VStack(spacing: 0) {
                Table(appState.filteredResults) {
                    TableColumn("Word", value: \.word)
                        .width(min: 220)

                    TableColumn("Count") { row in
                        Text("\(row.count)")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .width(min: 100, max: 120)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            }

            Text(appState.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(AppTheme.cardPadding)
        .glassCardStyle()
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
