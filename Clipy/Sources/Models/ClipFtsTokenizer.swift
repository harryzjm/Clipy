//
//  ClipFtsTokenizer.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation

/// Which tokenizer `clip_fts` is built with, and so how `FilterMatchMode.fts` reads a query.
///
/// The raw values are persisted in `UserDefaults` under `Preferences.Menu.ftsTokenizer`, so an
/// existing case must keep its string.
///
/// The preference is only a mirror: what the index *actually* uses is recorded in its own schema
/// (`ClipDB.ftsTokenizer()`), and switching rebuilds the table and clears the history —
/// `ClipService.switchFtsTokenizer(to:)` is the one path that does it.
enum ClipFtsTokenizer: String, CaseIterable, Identifiable {
    /// Words and single CJK characters, matched as typed.
    case verbatim
    /// Chinese characters only, matched by any of their readings in full or by initials
    /// (`zhongguo`, `zg`, `zhongg`). English and digits are not indexed at all.
    case pinyin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .verbatim: return "Verbatim"
        case .pinyin: return "Pinyin"
        }
    }
}
