import XCTest
@testable import WordFreqApp

final class TextLoaderTests: XCTestCase {
    func testDecodeTextPrefersUTF8AndNormalizesLineEndings() throws {
        let original = "first line\r\nsecond line\rthird line"
        let data = try XCTUnwrap(original.data(using: .utf8))

        let decoded = try TextLoader.decodeText(from: data, filename: "utf8.txt")

        XCTAssertEqual(decoded, "first line\nsecond line\nthird line")
    }

    func testDecodeTextSupportsISOLatin1() throws {
        let original = "resume résumé"
        let data = try XCTUnwrap(original.data(using: .isoLatin1))

        let decoded = try TextLoader.decodeText(from: data, filename: "latin1.txt")

        XCTAssertEqual(decoded, original)
    }

    func testDecodeTextFallsBackToWindows1252() throws {
        let original = "“résumé” – test"
        let data = try XCTUnwrap(original.data(using: .windowsCP1252))

        let decoded = try TextLoader.decodeText(from: data, filename: "cp1252.txt")

        XCTAssertEqual(decoded, original)
    }

    func testDecodeTextRejectsNulHeavyWrongDecode() throws {
        let original = "hello world"
        let data = try XCTUnwrap(original.data(using: .utf16LittleEndian))

        let decoded = try TextLoader.decodeText(from: data, filename: "utf16le.txt")

        XCTAssertEqual(decoded, original)
        XCTAssertFalse(decoded.contains("\0"))
    }

    func testPreviewFallbackForSingleLineUsesCharCaps() {
        let longSingleLine = String(repeating: "abc123", count: 3_000) // 18,000 chars

        let preview = AppState.buildPreviewData(from: longSingleLine)

        XCTAssertEqual(preview.compact.count, 4_000)
        XCTAssertEqual(preview.full.count, 12_000)
        XCTAssertFalse(preview.compact.contains("\n"))
        XCTAssertFalse(preview.full.contains("\n"))
        XCTAssertEqual(preview.debug.count, 300)
        XCTAssertEqual(preview.loadedChars, 18_000)
    }

    func testCSVExporterEscapesCommaQuoteAndNewline() throws {
        let rows: [WordCount] = [
            WordCount(word: "plain", count: 1),
            WordCount(word: "with,comma", count: 2),
            WordCount(word: "with\"quote", count: 3),
            WordCount(word: "line\nbreak", count: 4)
        ]
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("csv")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try CSVExporter.write(rows: rows, to: outputURL)
        let csv = try String(contentsOf: outputURL, encoding: .utf8)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)

        XCTAssertEqual(lines.first, "word,count")
        XCTAssertTrue(csv.contains("\"with,comma\",2"))
        XCTAssertTrue(csv.contains("\"with\"\"quote\",3"))
        XCTAssertTrue(csv.contains("\"line\nbreak\",4"))
    }

    func testFileTooLargeMessageIncludesFormattedActualAndLimitSizes() {
        let message = AppState.fileTooLargeMessage(fileSizeBytes: 40_300_000, limitBytes: 20 * 1_048_576)
        XCTAssertEqual(message, "File is 38.4 MB. WordFreq supports up to 20.0 MB.")
    }
}
