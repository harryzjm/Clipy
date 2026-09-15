//
//  CPYClipTable.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import WCDBSwift

/// Storage representation of a clipboard history entry.
///
/// `dataHash` is a content hash, so re-copying the same content upserts the existing row and
/// refreshes `updateTime` — that is what moves a repeated clip back to the top of the menu.
struct CPYClipTable: TableCodable, Equatable {

    static let tableName = "clip"

    var dataHash: String = ""
    var dataPath: String = ""
    var title: String = ""
    var primaryType: String = ""
    var updateTime: Int = 0
    var thumbnailPath: String = ""
    var isColorCode: Bool = false

    enum CodingKeys: String, CodingTableKey {
        typealias Root = CPYClipTable

        case dataHash = "data_hash"
        case dataPath = "data_path"
        case title
        case primaryType = "primary_type"
        case updateTime = "update_time"
        case thumbnailPath = "thumbnail_path"
        case isColorCode = "is_color_code"

        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(.dataHash, isPrimary: true, isNotNull: true)
            BindIndex(updateTime, namedWith: "_updateTimeIndex")
        }
    }
}

// MARK: - Convert DB type
extension CPYClipTable {
    var toClip: CPYClip {
        let clip = CPYClip()
        clip.dataHash = dataHash
        clip.dataPath = dataPath
        clip.title = title
        clip.primaryType = primaryType
        clip.updateTime = updateTime
        clip.thumbnailPath = thumbnailPath
        clip.isColorCode = isColorCode
        return clip
    }
}

extension CPYClip {
    var toTable: CPYClipTable {
        var table = CPYClipTable()
        table.dataHash = dataHash
        table.dataPath = dataPath
        table.title = title
        table.primaryType = primaryType
        table.updateTime = updateTime
        table.thumbnailPath = thumbnailPath
        table.isColorCode = isColorCode
        return table
    }
}
