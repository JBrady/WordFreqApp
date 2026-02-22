import Foundation

enum TextLoaderError: LocalizedError {
    case unsupportedFileType
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Unsupported file type. Please choose a .txt file exported from Google Docs."
        case .unreadableFile:
            return "Could not read this text file using common encodings."
        }
    }
}

enum TextLoader {
    static func loadText(at url: URL, requireTXTExtension: Bool = true) throws -> String {
        if requireTXTExtension, url.pathExtension.lowercased() != "txt" {
            throw TextLoaderError.unsupportedFileType
        }

        let data = try Data(contentsOf: url)
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .utf32,
            .utf32LittleEndian,
            .utf32BigEndian,
            .unicode,
            .isoLatin1,
            .windowsCP1252
        ]

        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }

        // Last-resort lossy decode keeps app usable for odd files.
        let fallback = String(decoding: data, as: UTF8.self)
        guard !fallback.isEmpty else {
            throw TextLoaderError.unreadableFile
        }
        return fallback
    }
}
