//
//  CPYClip.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2015/06/21.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

/// Domain projection of `CPYClipTable`.
///
/// Kept as a reference type so the menu-building and paste paths keep their existing
/// signatures; it holds no live database connection.
final class CPYClip {

    enum ClipType: Int, Codable {
        case text = 0
        case image = 1
        case color = 2
    }

    // MARK: - Properties
    var dataPath = ""
    var title = ""
    var dataHash = ""
    var primaryType = ""
    var updateTime = 0
    var thumbnailPath = ""
    var clipType: ClipType = .text
}
