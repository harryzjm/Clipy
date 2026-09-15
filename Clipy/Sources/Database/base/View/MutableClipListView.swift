//
//  MutableClipListView.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation

/// A live window onto the clipboard history, ordered and capped the way the history menu needs it.
///
/// Corresponds to `ServiceBox/base/View/MutableRelationshipView.swift`. `replay` runs inside the
/// still-open transaction, so it sees the uncommitted rows, and returns `true` only when the
/// visible window actually changed — that is what keeps the menu from rebuilding on no-op writes.
final class MutableClipListView {

    let ascending: Bool
    let limit: Int?

    private(set) var clips: [CPYClipTable]

    init(service: ClipServiceTransaction, ascending: Bool, limit: Int?) throws {
        self.ascending = ascending
        self.limit = limit
        self.clips = try service.clipDb.fetchClips(ascending: ascending, limit: limit)
    }

    func replay(service: ClipServiceTransaction, change: ClipChangeSet) -> Bool {
        guard !change.isEmpty else { return false }
        guard let new = try? service.clipDb.fetchClips(ascending: ascending, limit: limit) else { return false }
        guard new != clips else { return false }
        clips = new
        return true
    }

    func immutableView() -> Immutable {
        Immutable(self)
    }
}

extension MutableClipListView {
    final class Immutable {
        let clips: [CPYClipTable]

        init(_ view: MutableClipListView) {
            clips = view.clips
        }
    }
}
