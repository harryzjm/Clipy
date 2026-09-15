//
//  BoxChangeSet.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation

/// Immutable snapshot of what a clip transaction changed.
///
/// Built in `ClipServiceTransaction.beforeCommit()` from `ClipStatus`, then replayed into the
/// registered views by `ClipViewTracker`. Corresponds to `ServiceBox/base/SessionTransaction.swift`.
struct ClipChangeSet {

    let inserted: [CPYClipTable]
    let deleted: [ClipStatus.DeleteTarget]

    var isEmpty: Bool {
        inserted.isEmpty && deleted.isEmpty
    }

    init(status: ClipStatus) {
        self.inserted = status.inserted
        self.deleted = status.deleted
    }
}

/// Immutable snapshot of whether a snippet transaction changed anything.
struct SnippetChangeSet {

    let changed: Bool

    var isEmpty: Bool {
        !changed
    }

    init(status: SnippetStatus) {
        self.changed = status.changed
    }
}
