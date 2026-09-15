//
//  CPYSnippet.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2015/06/21.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa

/// Domain projection of `CPYSnippetTable`.
///
/// Subclasses `NSObject` because `CPYSnippetsEditorWindowController` uses instances directly as
/// `NSOutlineView` items, which needs stable `isEqual:` identity.
final class CPYSnippet: NSObject {

    // MARK: - Properties
    @objc dynamic var index = 0
    @objc dynamic var enable = true
    @objc dynamic var title = ""
    @objc dynamic var content = ""
    @objc dynamic var identifier = UUID().uuidString

    /// Owning folder. Replaces Realm's `LinkingObjects` inverse relationship.
    /// Deliberately absent from `CodingKeys` so the exported JSON format stays unchanged.
    var folderIdentifier = ""

    override init() {
        super.init()
    }

    init(copying other: CPYSnippet) {
        super.init()
        index = other.index
        enable = other.enable
        title = other.title
        content = other.content
        identifier = other.identifier
        folderIdentifier = other.folderIdentifier
    }
}

extension CPYSnippet: Codable {

    enum CodingKeys: String, CodingKey {
        case index
        case enable
        case title
        case content
        case identifier
    }

    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Int.self, forKey: .index)
        enable = try container.decode(Bool.self, forKey: .enable)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        identifier = try container.decode(String.self, forKey: .identifier)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(enable, forKey: .enable)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(identifier, forKey: .identifier)
    }
}
