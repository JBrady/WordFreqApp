import Foundation

enum TextLoaderError: LocalizedError {
    case unsupportedFileType
    case unreadableFile(filename: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Unsupported file type. Please choose a .txt file exported from Google Docs."
        case .unreadableFile(let filename):
            return "Could not decode \(filename) using common text encodings. Please re-save the file as UTF-8 and try again."
        }
    }
}

enum TextLoader {
    static func loadText(at url: URL, requireTXTExtension: Bool = true) throws -> String {
        if requireTXTExtension, url.pathExtension.lowercased() != "txt" {
            throw TextLoaderError.unsupportedFileType
        }

        let data = try Data(contentsOf: url)
        return try decodeText(from: data, filename: url.lastPathComponent)
    }

    static func decodeText(from data: Data, filename: String) throws -> String {
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .macOSRoman,
            .isoLatin1,
            .windowsCP1252
        ]

        for encoding in encodings {
            guard let decoded = String(data: data, encoding: encoding) else {
                continue
            }

            guard looksLikeValidDecode(decoded, sourceData: data, encoding: encoding) else {
                continue
            }

            return normalizeLineEndings(decoded)
        }

        throw TextLoaderError.unreadableFile(filename: filename)
    }

    private static func normalizeLineEndings(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func looksLikeValidDecode(
        _ text: String,
        sourceData: Data,
        encoding: String.Encoding
    ) -> Bool {
        guard !text.isEmpty else { return true }
        guard encodingLooksPlausible(for: sourceData, encoding: encoding) else {
            return false
        }

        let scalars = text.unicodeScalars
        let total = max(scalars.count, 1)
        var replacementCount = 0
        var nulCount = 0
        var disallowedControlCount = 0
        var totalLetterCount = 0
        var lowercaseLetterCount = 0
        var nonASCIILetterCount = 0
        var uppercaseNonASCIILetterCount = 0

        for scalar in scalars {
            if scalar.value == 0xFFFD {
                replacementCount += 1
            }
            if scalar.value == 0 {
                nulCount += 1
            }
            if scalar.properties.generalCategory == .control,
               scalar != "\n",
               scalar != "\r",
               scalar != "\t" {
                disallowedControlCount += 1
            }

            if scalar.properties.isAlphabetic {
                totalLetterCount += 1
                if CharacterSet.lowercaseLetters.contains(scalar) {
                    lowercaseLetterCount += 1
                }
                if scalar.value > 0x7F {
                    nonASCIILetterCount += 1
                    if CharacterSet.uppercaseLetters.contains(scalar) {
                        uppercaseNonASCIILetterCount += 1
                    }
                }
            }
        }

        let replacementRatio = Double(replacementCount) / Double(total)
        let nulRatio = Double(nulCount) / Double(total)
        let isSuspiciousUppercaseNonASCII: Bool = {
            guard nonASCIILetterCount >= 2, totalLetterCount > 0 else { return false }
            let uppercaseNonASCIIRatio = Double(uppercaseNonASCIILetterCount) / Double(nonASCIILetterCount)
            let lowercaseRatio = Double(lowercaseLetterCount) / Double(totalLetterCount)
            return uppercaseNonASCIIRatio > 0.7 && lowercaseRatio > 0.5
        }()

        return replacementRatio < 0.02
            && nulRatio < 0.02
            && disallowedControlCount == 0
            && !isSuspiciousUppercaseNonASCII
    }

    private static func encodingLooksPlausible(for data: Data, encoding: String.Encoding) -> Bool {
        let hasUTF16LEBOM = data.starts(with: [0xFF, 0xFE])
        let hasUTF16BEBOM = data.starts(with: [0xFE, 0xFF])
        let nulByteRatio = Double(data.filter { $0 == 0 }.count) / Double(max(data.count, 1))

        switch encoding {
        case .utf16:
            return hasUTF16LEBOM || hasUTF16BEBOM
        case .utf16LittleEndian:
            return hasUTF16LEBOM || nulByteRatio >= 0.10
        case .utf16BigEndian:
            return hasUTF16BEBOM || nulByteRatio >= 0.10
        case .macOSRoman:
            // Common Windows-1252 punctuation bytes should prefer .windowsCP1252 over MacRoman.
            let cp1252PunctuationBytes: Set<UInt8> = [
                0x80, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
                0x89, 0x8B, 0x91, 0x92, 0x93, 0x94, 0x95,
                0x96, 0x97, 0x99, 0x9B
            ]
            return !data.contains(where: { cp1252PunctuationBytes.contains($0) })
        default:
            return true
        }
    }
}
