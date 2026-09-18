//
//  MenuIcon.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Cocoa

/// The two template images menu items are drawn with.
///
/// `Asset.Common.icon*.image` hands back AppKit's shared cached `NSImage`, so `isTemplate` and
/// `size` must be applied exactly once rather than per item. Both `SnippetMenu` and `FilterMenu`
/// read these, and the lazy `static let` guarantees the configuration has run whichever of them
/// gets there first — which is why the folder icon must not be reached through `Asset` directly.
enum MenuIcon {

    static let folder: NSImage = {
        let image = Asset.Common.iconFolder.image
        image.isTemplate = true
        image.size = NSSize(width: 15, height: 13)
        return image
    }()

    static let snippet: NSImage = {
        let image = Asset.Common.iconText.image
        image.isTemplate = true
        image.size = NSSize(width: 12, height: 13)
        return image
    }()
}
