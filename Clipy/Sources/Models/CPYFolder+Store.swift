//
//  CPYFolder+Store.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation

/// Compatibility shim over `ClipyBox`.
///
/// The Realm models were active records that opened their own Realm inside `merge()`, `remove()`
/// and friends. Those method names are kept so the snippets editor reads the same, but the work
/// now goes through the store's transaction API. The database layer itself stays free of this.
extension CPYFolder {

    /// A new folder positioned after `folders`, which the caller already holds sorted by index.
    static func create(after folders: [CPYFolder]) -> CPYFolder {
        let folder = CPYFolder()
        folder.title = "untitled folder"
        folder.index = (folders.map { $0.index }.max() ?? -1) + 1
        return folder
    }

    func merge() {
        let table = toTable
        AppEnvironment.current.box.snippetWrite { try $0.snippetDb.upsertFolder(table) }
    }

    func remove() {
        let identifier = self.identifier
        AppEnvironment.current.box.snippetWrite { try $0.removeFolder(identifier: identifier) }
    }

    /// Appends a snippet to this folder.
    func mergeSnippet(_ snippet: CPYSnippet) {
        // Re-parent the live object too, so a later `merge()` from the editor does not write the
        // stale owner back.
        snippet.folderIdentifier = identifier
        let copy = CPYSnippet(copying: snippet)
        let identifier = self.identifier
        AppEnvironment.current.box.snippetWrite { try $0.appendSnippet(copy, folderIdentifier: identifier) }
    }

    /// Moves a snippet into this folder at `index`, renumbering the folder afterwards.
    func insertSnippet(_ snippet: CPYSnippet, index: Int) {
        snippet.folderIdentifier = identifier
        let copy = CPYSnippet(copying: snippet)
        let identifier = self.identifier
        AppEnvironment.current.box.snippetWrite {
            try $0.insertSnippet(copy, folderIdentifier: identifier, index: index)
        }
    }

    /// Detaches a snippet from this folder. A no-op if it has already been re-parented, which is
    /// what makes the editor's insert-then-remove cross-folder move safe.
    func removeSnippet(_ snippet: CPYSnippet) {
        let identifier = snippet.identifier
        let folderIdentifier = self.identifier
        AppEnvironment.current.box.snippetWrite {
            try $0.removeSnippet(identifier: identifier, fromFolder: folderIdentifier)
        }
    }

    /// Renumbers folders from the array order, in one transaction.
    static func rearrangesIndex(_ folders: [CPYFolder]) {
        folders.enumerated().forEach { $0.element.index = $0.offset }
        let snapshot = folders.map { CPYFolder(shallowCopying: $0) }
        AppEnvironment.current.box.snippetWrite { try $0.rearrangeFolders(snapshot) }
    }

    /// Renumbers this folder's snippets from the array order, in one transaction.
    func rearrangesSnippetIndex() {
        snippets.enumerated().forEach {
            $0.element.index = $0.offset
            $0.element.folderIdentifier = identifier
        }
        let snapshot = snippets.map { CPYSnippet(copying: $0) }
        AppEnvironment.current.box.snippetWrite { try $0.rearrangeSnippets(snapshot) }
    }
}

extension CPYFolder {
    /// Copy without the snippets, for handing a value snapshot to a background transaction.
    convenience init(shallowCopying other: CPYFolder) {
        self.init()
        index = other.index
        enable = other.enable
        title = other.title
        identifier = other.identifier
    }
}
