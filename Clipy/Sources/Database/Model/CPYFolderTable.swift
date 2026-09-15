//
//  CPYFolderTable.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import WCDBSwift

/// Storage representation of a snippet folder.
///
/// `index` keeps its Swift name but maps to `folder_index`, because `index` is a SQLite
/// reserved word.
struct CPYFolderTable: TableCodable, Equatable {

    static let tableName = "folder"

    var identifier: String = ""
    var index: Int = 0
    var enable: Bool = true
    var title: String = ""

    enum CodingKeys: String, CodingTableKey {
        typealias Root = CPYFolderTable

        case identifier
        case index = "folder_index"
        case enable
        case title

        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(.identifier, isPrimary: true, isNotNull: true)
            BindIndex(index, namedWith: "_folderIndexIndex")
        }
    }
}

// MARK: - Convert DB type
extension CPYFolderTable {
    /// Builds the domain object. `snippets` is filled in separately by the DAO.
    func toFolder(snippets: [CPYSnippet] = []) -> CPYFolder {
        let folder = CPYFolder()
        folder.identifier = identifier
        folder.index = index
        folder.enable = enable
        folder.title = title
        folder.snippets = snippets
        return folder
    }
}

extension CPYFolder {
    var toTable: CPYFolderTable {
        var table = CPYFolderTable()
        table.identifier = identifier
        table.index = index
        table.enable = enable
        table.title = title
        return table
    }
}
