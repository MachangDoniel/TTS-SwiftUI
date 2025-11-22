//
//  TTSSentenceParser.swift
//  TTS
//
//  Created by Doniel Tripura on 11/2/25.
//


import Foundation

final class TTSSentenceParser {

    func splitIntoSentencesPreservingHeadings(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let rawLines = normalized.components(separatedBy: "\n")

        let bulletPrefixes = ["- ", "• ", "* ", "– ", "— "]
        let numberedRegex = try? NSRegularExpression(pattern: "^\\s*\\d+[\\.)]\\s+", options: [])
        let headingColonSuffix: Character = ":"
        let sentenceRegex = try? NSRegularExpression(
            pattern: "(?<!\\b(?:Mr|Mrs|Ms|Dr|Prof|Sr|Jr|St|vs|No|Fig|e|i)\\.)(?<=[.!?])\\s+",
            options: [.caseInsensitive]
        )

        func isBulletOrNumbered(_ s: String) -> Bool {
            if bulletPrefixes.contains(where: { s.hasPrefix($0) }) { return true }
            if let re = numberedRegex,
               re.firstMatch(in: s, options: [], range: NSRange(location: 0, length: (s as NSString).length)) != nil {
                return true
            }
            return false
        }

        func isLikelyHeading(_ s: String) -> Bool {
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }
            if trimmed.last == headingColonSuffix { return true }
            if let last = trimmed.unicodeScalars.last,
               !CharacterSet(charactersIn: ".!?").contains(last),
               trimmed.count <= 80 {
                let words = trimmed.split(separator: " ")
                let titleCasedTokens = words.filter { token in
                    guard let first = token.first else { return false }
                    return String(first).uppercased() == String(first)
                        && token.dropFirst().allSatisfy { $0.isLowercase || !$0.isLetter }
                }
                return titleCasedTokens.count >= max(1, words.count / 2)
            }
            return false
        }

        var paragraphs: [String] = []
        var currentPara: [String] = []

        func flushPara() {
            if !currentPara.isEmpty {
                paragraphs.append(currentPara.joined(separator: " "))
                currentPara.removeAll()
            }
        }

        for raw in rawLines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                flushPara(); continue
            }
            if isBulletOrNumbered(line) || isLikelyHeading(line) {
                flushPara()
                paragraphs.append(line)
                continue
            }
            currentPara.append(line)
        }
        flushPara()

        var results: [String] = []
        for para in paragraphs {
            if isBulletOrNumbered(para) || isLikelyHeading(para) {
                results.append(para)
                continue
            }

            if let re = sentenceRegex {
                let ns = para as NSString
                let range = NSRange(location: 0, length: ns.length)
                var lastIndex = 0
                re.enumerateMatches(in: para, options: [], range: range) { match, _, _ in
                    guard let match = match else { return }
                    let end = match.range.location + match.range.length
                    let sentence = ns.substring(with: NSRange(location: lastIndex, length: end - lastIndex))
                        .trimmingCharacters(in: .whitespaces)
                    if !sentence.isEmpty { results.append(sentence) }
                    lastIndex = end
                }
                if lastIndex < ns.length {
                    let tail = ns.substring(from: lastIndex).trimmingCharacters(in: .whitespaces)
                    if !tail.isEmpty { results.append(tail) }
                }
            } else {
                let fallback = para.split(whereSeparator: { ".!?".contains($0) })
                results.append(contentsOf: fallback.map(String.init))
            }
        }

        return results.map {
            $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        }.filter { !$0.isEmpty }
    }
}
