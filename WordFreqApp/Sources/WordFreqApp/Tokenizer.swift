import Foundation

struct TokenizerOptions {
    let keepInternalApostrophes: Bool
    let includeNumbers: Bool
    let allowNonLatinLetters: Bool
}

enum Tokenizer {
    static func tokenize(_ text: String, options: TokenizerOptions) -> [String] {
        var tokens: [String] = []
        var current = ""
        let chars = Array(text)

        func flush() {
            guard !current.isEmpty else { return }
            tokens.append(current)
            current.removeAll(keepingCapacity: true)
        }

        for index in chars.indices {
            let c = chars[index]

            if isHyphen(c) {
                flush()
                continue
            }

            if c == "'" {
                if options.keepInternalApostrophes {
                    let hasPrevTokenChar = !current.isEmpty
                    let hasNextTokenChar: Bool = {
                        guard index < chars.index(before: chars.endIndex) else { return false }
                        let next = chars[chars.index(after: index)]
                        return isTokenCharacter(
                            next,
                            includeNumbers: options.includeNumbers,
                            allowNonLatinLetters: options.allowNonLatinLetters
                        )
                    }()

                    if hasPrevTokenChar && hasNextTokenChar {
                        current.append(c)
                    }
                }
                continue
            }

            if isTokenCharacter(
                c,
                includeNumbers: options.includeNumbers,
                allowNonLatinLetters: options.allowNonLatinLetters
            ) {
                current.append(c)
            } else {
                flush()
            }
        }

        flush()
        return tokens
    }

    private static func isTokenCharacter(
        _ c: Character,
        includeNumbers: Bool,
        allowNonLatinLetters: Bool
    ) -> Bool {
        guard let scalar = c.unicodeScalars.first, c.unicodeScalars.count == 1 else {
            return false
        }

        if scalar.properties.isAlphabetic {
            if allowNonLatinLetters {
                return true
            }
            return isLatinLetter(scalar)
        }

        if includeNumbers, scalar.properties.numericType != nil {
            return true
        }

        return false
    }

    private static func isHyphen(_ c: Character) -> Bool {
        ["-", "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2015}"]
            .contains(c)
    }

    // Conservative Latin-script block coverage for English/Western text by default.
    private static func isLatinLetter(_ scalar: UnicodeScalar) -> Bool {
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
