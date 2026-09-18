//
//  CPYClipContentTable.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation
import WCDBSwift

/// Inline clipboard payloads, keyed by the same `data_hash` as `clip`.
///
/// A side table rather than a column on `clip`: every list read decodes `clip` in full
/// (`ClipDB.fetchClips` passes no projection, so WCDB substitutes `Properties.all`), and
/// `MutableClipListView.replay` then value-compares each row. A blob living there would be read
/// and compared on every keystroke in the history filter, for a payload only the paste path ever
/// opens.
///
/// Only clips whose payload fits inline get a row here; an overflowed payload lives in a
/// `file/<uuid>` file instead, and `insertClip` passes nil to keep the two from coexisting.
///
/// Rows are removed with their clip — by the `clip_content_ad` trigger for targeted and
/// predicate deletes, and explicitly by `deleteAllClips()`. See `ClipDB.setContent(_:forDataHash:)`
/// for the write side.
struct CPYClipContentTable: TableCodable {

    static let tableName = "clip_content"

    var dataHash: String = ""
    var content: Data = Data()

    enum CodingKeys: String, CodingTableKey {
        typealias Root = CPYClipContentTable

        case dataHash = "data_hash"
        case content

        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(.dataHash, isPrimary: true, isNotNull: true)
        }
    }
}
