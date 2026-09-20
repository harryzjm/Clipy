//
//  SnippetsDragItem.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import CoreTransferable
import UniformTypeIdentifiers

extension UTType {

    /// Pasteboard types for a sidebar row drag. Both conform to `public.data` and nothing else,
    /// deliberately: the editor window puts a `.dropDestination(for: URL.self)` on its root for
    /// the JSON import (`SnippetsEditorView`), and anything coercible to a URL or to text would
    /// be offered to that target instead of to the row under the pointer.
    ///
    /// The identifiers are literals rather than derived from `Bundle.main.bundleIdentifier`:
    /// Debug and Release ship different bundle ids (`…Clipy.debug` / `…Clipy`) and both builds
    /// have to speak the same type.
    static let clipySnippetsFolderRow = UTType(exportedAs: "com.clipy-app.clipy.snippets-folder-row",
                                               conformingTo: .data)

    /// Folders and snippets get *separate* types rather than one payload with a kind field,
    /// because `DropInfo` can only be asked which types are present, never for the value, until
    /// the drop itself. Two types is what lets a row decide during the hover whether it is a
    /// legal target and whether to draw an indicator at all.
    static let clipySnippetsSnippetRow = UTType(exportedAs: "com.clipy-app.clipy.snippets-snippet-row",
                                                conformingTo: .data)
}

/// Identity only. The store resolves it against its working copy, so a payload that went stale
/// while the drag was in flight cannot misroute a write.
struct SnippetsFolderDragItem: Codable, Hashable, Transferable {

    let identifier: String

    /// `CodableRepresentation` alone — no `ProxyRepresentation`. A text proxy would make the
    /// payload droppable into the snippet content editor and would re-expose it to the
    /// window-level URL import target.
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .clipySnippetsFolderRow)
    }
}

struct SnippetsSnippetDragItem: Codable, Hashable, Transferable {

    let identifier: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .clipySnippetsSnippetRow)
    }
}

/// Where a drop lands relative to the row it was made on.
enum SnippetsDropPosition {
    case before
    case after
}

/// What a row draws while a drag hovers over it. `nil` means "not a target for this payload",
/// which is also how an illegal drag (a folder over a snippet row) renders: nothing at all.
enum SnippetsDropIndicator: Equatable {
    /// Insertion line at the row's leading edge.
    case before
    /// Insertion line at the row's trailing edge.
    case after
    /// The whole row highlights: the payload goes inside this folder.
    case into
}
