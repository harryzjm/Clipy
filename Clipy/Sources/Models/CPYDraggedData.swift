//
//  CPYDraggedData.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/07/14.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

final class CPYDraggedData: NSObject, NSCoding {

    // MARK: - Properties
    let type: DragType
    let folderIdentifier: String?
    let snippetIdentifier: String?
    let index: Int

    // MARK: - Enums
    enum DragType: Int {
        case folder, snippet
    }

    // MARK: - Initialize
    init(type: DragType, folderIdentifier: String?, snippetIdentifier: String?, index: Int) {
        self.type = type
        self.folderIdentifier = folderIdentifier
        self.snippetIdentifier = snippetIdentifier
        self.index = index
        super.init()
    }

    // MARK: - NSCoding
    required init?(coder: NSCoder) {
        self.type = DragType(rawValue: coder.decodeInteger(forKey: "type")) ?? .folder
        self.folderIdentifier = coder.decodeObject(forKey: "folderIdentifier") as? String
        self.snippetIdentifier = coder.decodeObject(forKey: "snippetIdentifier") as? String
        self.index = coder.decodeInteger(forKey: "index")
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(type.rawValue, forKey: "type")
        coder.encode(folderIdentifier, forKey: "folderIdentifier")
        coder.encode(snippetIdentifier, forKey: "snippetIdentifier")
        coder.encode(index, forKey: "index")
    }
}
