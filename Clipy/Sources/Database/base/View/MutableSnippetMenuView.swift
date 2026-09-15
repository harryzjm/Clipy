//
//  MutableSnippetMenuView.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation

/// A live view of the whole snippet graph, shaped the way the snippet menu and the editor need it.
///
/// Replaces the Realm `NotificationToken` on `CPYFolder` that used to drive `MenuManager`.
final class MutableSnippetMenuView {

    private(set) var folders: [CPYFolder]

    init(service: SnippetServiceTransaction) throws {
        self.folders = try service.fetchFolders()
    }

    func replay(service: SnippetServiceTransaction, change: SnippetChangeSet) -> Bool {
        guard !change.isEmpty else { return false }
        guard let new = try? service.fetchFolders() else { return false }
        guard !MutableSnippetMenuView.isEqual(new, folders) else { return false }
        folders = new
        return true
    }

    func immutableView() -> Immutable {
        Immutable(self)
    }

    /// Structural comparison. `CPYFolder` is a reference type with identity equality, so the
    /// freshly fetched objects are never `==` to the previous ones.
    private static func isEqual(_ lhs: [CPYFolder], _ rhs: [CPYFolder]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            left.toTable == right.toTable
                && left.snippets.count == right.snippets.count
                && zip(left.snippets, right.snippets).allSatisfy { $0.toTable == $1.toTable }
        }
    }
}

extension MutableSnippetMenuView {
    final class Immutable {
        let folders: [CPYFolder]

        init(_ view: MutableSnippetMenuView) {
            folders = view.folders
        }
    }
}
