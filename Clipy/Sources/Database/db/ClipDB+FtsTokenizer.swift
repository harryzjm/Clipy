//
//  ClipDB+FtsTokenizer.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation
import WCDBSwift

// MARK: - FTS tokenizer
private extension ClipFtsTokenizer {
    /// The name WCDB registers this tokenizer under, as it appears in `tokenize = …`.
    var wcdbName: String {
        switch self {
        case .verbatim: return BuiltinTokenizer.Verbatim
        case .pinyin: return BuiltinTokenizer.Pinyin
        }
    }
}

extension ClipDB {
    /// The tokenizer `clip_fts` was actually created with, read off its own schema.
    ///
    /// This, not `Preferences.Menu.ftsTokenizer`, is the source of truth: the preference is only
    /// written after a switch commits, and is realigned to this at launch.
    func ftsTokenizer() throws -> ClipFtsTokenizer {
        let sql = try db.getValue(on: Column(named: "sql"),
                                  fromTable: "sqlite_master",
                                  where: Column(named: "type") == "table"
                                      && Column(named: "name") == CPYClipFtsTable.tableName).stringValue
        return sql.contains(ClipFtsTokenizer.pinyin.wcdbName) ? .pinyin : .verbatim
    }

    /// Drops `clip_fts` and creates it again, empty, under `tokenizer`.
    ///
    /// fts5 cannot change a table's tokenizer in place. The `clip_fts_*` triggers live on `clip`
    /// and name `clip_fts` only inside their bodies, so they survive the drop and write into the
    /// new table from the next insert on. The columns are spelled exactly as `CPYClipFtsTable`
    /// declares them — `title` first, which `highlight()` addresses by number.
    ///
    /// Leaves the index empty rather than repopulating it: the only caller clears the history in
    /// the same transaction. The caller owns that transaction.
    func recreateFtsIndex(tokenizer: ClipFtsTokenizer) throws {
        if tokenizer == .pinyin {
            _ = PinyinDictionary.loaded
        }
        try db.drop(table: CPYClipFtsTable.tableName)
        try db.exec(StatementCreateVirtualTable()
            .create(virtualTable: CPYClipFtsTable.tableName)
            .using(module: .FTS5)
            .arguments(CPYClipFtsTable.CodingKeys.title.rawValue,
                       "\(CPYClipFtsTable.CodingKeys.dataHash.rawValue) UNINDEXED",
                       "tokenize = \(tokenizer.wcdbName)"))
    }
}
