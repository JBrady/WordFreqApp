import Foundation

struct TokenizerOptions {
    let keepInternalApostrophes: Bool
    let includeNumbers: Bool
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
                        return isTokenCharacter(next, includeNumbers: options.includeNumbers)
                    }()

                    if hasPrevTokenChar && hasNextTokenChar {
                        current.append(c)
                    }
                }
                continue
            }

            if isTokenCharacter(c, includeNumbers: options.includeNumbers) {
                current.append(c)
            } else {
                flush()
            }
        }

        flush()
        return tokens
    }

    private static func isTokenCharacter(_ c: Character, includeNumbers: Bool) -> Bool {
        guard let scalar = c.unicodeScalars.first, c.unicodeScalars.count == 1 else {
            return false
        }

        let value = scalar.value
        let isLowerASCIIAlpha = (97...122).contains(value)
        let isASCIIDigit = (48...57).contains(value)
        return isLowerASCIIAlpha || (includeNumbers && isASCIIDigit)
    }

    private static func isHyphen(_ c: Character) -> Bool {
        ["-", "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2015}"]
            .contains(c)
    }
}
