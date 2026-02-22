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
}
