//
//  CPYClipFtsTable.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation
import WCDBSwift

/// Full-text index over `CPYClipTable.title`, used by `FilterMatchMode.fts`.
///
/// A shadow of `clip`, not a source of truth: SQL triggers on `clip` keep it in step (see
/// `ClipDB.createFtsTriggers`). Every row's rowid is pinned to its clip's rowid, because rowid
/// is the only key fts5 can seek on — an equality test against any other column falls back to a
/// full scan of the shadow table. `data_hash` rides along as payload so a hit can be joined back
/// to its `clip` row.
///
/// Not an external-content table (`content=`): that form keys the index by the content table's
/// rowid *implicitly*, and `insertClip` uses `INSERT OR REPLACE`, which hands a repeated copy a
/// fresh rowid without firing AFTER DELETE for the row it dropped. Writing the rowid explicitly
/// and clearing the stale row in a BEFORE INSERT trigger keeps the mirror honest without taking
/// on that constraint.
struct CPYClipFtsTable: TableCodable {

    static let tableName = "clip_fts"

    /// `title` must stay the first case. A virtual table's column order follows declaration
    /// order, and `highlight(clip_fts, 0, …)` addresses the column by number — reordering these
    /// would silently highlight `data_hash` instead.
    var title: String = ""
    var dataHash: String = ""

    /// Column number of `title`, for `highlight()`.
    static let titleColumnIndex = 0

    enum CodingKeys: String, CodingTableKey {
        typealias Root = CPYClipFtsTable

        case title
        case dataHash = "data_hash"

        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindVirtualTable(withModule: .FTS5, and: BuiltinTokenizer.Verbatim)
            // Only `title` is searchable; `data_hash` is payload the query reads back.
            BindColumnConstraint(.dataHash, isNotIndexed: true)
        }
    }
}
