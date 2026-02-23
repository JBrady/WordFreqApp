import SwiftUI

struct DebugView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Debug Diagnostics", systemImage: "ladybug")
                    .font(.system(.title3, design: .rounded).weight(.bold))

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Text("Loaded \(appState.debugLoadedChars) chars | Tokens \(appState.debugTokenCount) | Ignored \(appState.debugBuiltInIgnoredCount) built-in + \(appState.debugAdditionalIgnoredCount) additional = \(appState.debugMergedIgnoredCount)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Tokenizer Sample Tokens")
                .font(.subheadline.weight(.semibold))

            ScrollView(.vertical, showsIndicators: true) {
                Text(appState.debugSampleTokens.isEmpty ? "No tokens captured yet." : appState.debugSampleTokens.joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minHeight: 260)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 420)
        .background(AppTheme.pageGradient(for: .dark).opacity(0.35))
    }
}
