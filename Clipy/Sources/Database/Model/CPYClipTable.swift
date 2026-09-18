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
    var thumbnailKey: String = ""
    var clipType: Int = CPYClip.ClipType.text.rawValue

    enum CodingKeys: String, CodingTableKey {
        typealias Root = CPYClipTable

        case dataHash = "data_hash"
        case dataPath = "data_path"
        case title
        case primaryType = "primary_type"
        case updateTime = "update_time"
        case thumbnailKey = "thumbnail_key"
        case clipType = "clip_type"

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
        clip.thumbnailKey = thumbnailKey
        clip.clipType = CPYClip.ClipType(rawValue: clipType) ?? .text
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
        table.thumbnailKey = thumbnailKey
        table.clipType = clipType.rawValue
        return table
    }
}
