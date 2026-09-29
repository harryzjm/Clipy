//
//  PinyinDictionary.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation

/// The character → readings table `ClipyTokenizer` indexes Chinese characters with.
///
/// Every reading of a character is kept (`重 zhong chong tong`), which is what makes a polyphone
/// findable under each of them. The file is generated — see `script/gen_pinyin_dict.py`.
enum PinyinDictionary {

    static let resourceName = "pinyin"

    /// Keyed by Unicode scalar; each value is what the tokenizer stacks on the character, as
    /// UTF-8: every reading followed by its initial, duplicates dropped (`zhong z chong c tong t`).
    ///
    /// Loaded once — `warmUp()` starts it in the background as soon as the tokenizer is
    /// registered, and any lookup that gets here first waits for that same load. Swift runs a
    /// lazy static's initializer exactly once and thread-safely, and fts5 may tokenize on any
    /// queue.
    static let readings: [UInt32: [[UInt8]]] = {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            lError("pinyin dictionary missing from the bundle; Chinese characters will match only as written")
            return [:]
        }
        let dictionary = parse(text)
        var table: [UInt32: [[UInt8]]] = [:]
        table.reserveCapacity(dictionary.count)
        for (character, pinyin) in dictionary {
            let scalars = character.unicodeScalars
            guard scalars.count == 1, let scalar = scalars.first else { continue }
            table[scalar.value] = tokens(for: pinyin)
        }
        lInfo("pinyin dictionary loaded: \(table.count) characters")
        return table
    }()

    /// Loads `readings` off the calling thread, so the first search does not pay for it.
    static func warmUp() {
        DispatchQueue.global(qos: .utility).async { _ = readings }
    }

    /// `重 zhong chong` per line; `#` starts a comment line.
    static func parse(_ text: String) -> [String: [String]] {
        var dictionary: [String: [String]] = [:]
        text.enumerateLines { line, _ in
            guard !line.hasPrefix("#") else { return }
            let fields = line.split(separator: " ")
            guard fields.count >= 2 else { return }
            dictionary[String(fields[0])] = fields.dropFirst().map(String.init)
        }
        return dictionary
    }

    /// Each reading, then its first letter — the order WCDB's own Pinyin tokenizer used.
    static func tokens(for readings: [String]) -> [[UInt8]] {
        var seen: Set<[UInt8]> = []
        var tokens: [[UInt8]] = []
        for reading in readings {
            let full = Array(reading.utf8)
            guard let initial = full.first else { continue }
            for token in [full, [initial]] where seen.insert(token).inserted {
                tokens.append(token)
            }
        }
        return tokens
    }
}
