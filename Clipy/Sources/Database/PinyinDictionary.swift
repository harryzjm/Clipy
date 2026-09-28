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
import WCDBSwift

/// Feeds WCDB's Pinyin tokenizer the character → readings table it indexes with.
///
/// The table is process-global C++ state inside WCDB, and without it the tokenizer quietly emits
/// no tokens at all — rows would go into `clip_fts` unsearchable. So it has to be loaded before
/// anything writes to a Pinyin index: `ClipDB` touches `loaded` when it opens onto one, and
/// before it creates one.
///
/// Loaded lazily and once: a Verbatim index never needs it, so it costs Verbatim users nothing.
///
/// Every reading of a character is kept (`重 zhong chong tong`), which is what makes a polyphone
/// findable under each of them. The file is generated — see `script/gen_pinyin_dict.py`.
enum PinyinDictionary {

    static let resourceName = "pinyin"

    /// Swift runs a lazy static's initializer exactly once, thread-safely, which is the whole
    /// point of spelling it this way.
    static let loaded: Void = {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            lError("pinyin dictionary missing from the bundle; the Pinyin index will match nothing")
            return
        }
        let dictionary = parse(text)
        Database.config(pinyinDict: dictionary)
        lInfo("pinyin dictionary loaded: \(dictionary.count) characters")
    }()

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
}
