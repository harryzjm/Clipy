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
/// `ClipDB.migrationList()`). `data_hash` joins a hit back to its row; `update_time` is
/// duplicated so the FTS query can order and limit on its own — `highlight()` only works in a
/// query against the FTS table itself, so that query cannot borrow `clip`'s ordering.
///
/// Not an external-content table (`content=`): `insertClip` uses `INSERT OR REPLACE`, which
/// gives a repeated copy a fresh implicit rowid, and external content is keyed by rowid.
struct CPYClipFtsTable: TableCodable {

    static let tableName = "clip_fts"

    /// `title` must stay the first case. A virtual table's column order follows declaration
    /// order, and `highlight(clip_fts, 0, …)` addresses the column by number — reordering these
    /// would silently highlight `data_hash` instead.
    var title: String = ""
    var dataHash: String = ""
    var updateTime: Int = 0

    /// Column number of `title`, for `highlight()`.
    static let titleColumnIndex = 0

    enum CodingKeys: String, CodingTableKey {
        typealias Root = CPYClipFtsTable

        case title
        case dataHash = "data_hash"
        case updateTime = "update_time"

        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindVirtualTable(withModule: .FTS5, and: BuiltinTokenizer.Verbatim)
            // Only `title` is searchable; the other two are payload the query reads back.
            BindColumnConstraint(.dataHash, isNotIndexed: true)
            BindColumnConstraint(.updateTime, isNotIndexed: true)
        }
    }
}
