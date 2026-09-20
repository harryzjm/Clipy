//
//  SnippetsRowDropDelegate.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI
import UniformTypeIdentifiers

/// The drop half of the sidebar's drag and drop, shared by folder rows and snippet rows.
///
/// A `DropDelegate` rather than `.dropDestination(for:)` because only `dropUpdated(info:)` hands
/// over the pointer position continuously: that is what lets the row draw an insertion line on
/// the edge the drop will actually land on. `.dropDestination` offers a single `isTargeted`
/// boolean, which cannot say "before" from "after".
///
/// None of this goes through `List`'s own reorder machinery, which is the point — that machinery
/// only ever started a drag from the empty stretch of a row, because the `Text` and the icon
/// consume the mouse-down before the table row sees it.
struct SnippetsRowDropDelegate: DropDelegate {

    /// The row this delegate is attached to.
    let row: SnippetsSidebarItem
    /// Measured by the row, for the top-half / bottom-half split. Zero until the first layout.
    let rowHeight: CGFloat
    let store: SnippetsEditorStore
    /// One target for the whole list, so a drag that ends elsewhere cannot leave a line behind.
    let state: SnippetsDropState

    /// Both types are offered to every row; this is what refuses a folder dragged onto a snippet
    /// row. Returning false here means no `dropEntered`, so an illegal target never lights up.
    func validateDrop(info: DropInfo) -> Bool {
        resolved(for: info) != nil
    }

    func dropEntered(info: DropInfo) {
        update(with: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: update(with: info) == nil ? .cancel : .move)
    }

    func dropExited(info: DropInfo) {
        state.exit(row.id)
    }

    func performDrop(info: DropInfo) -> Bool {
        let resolved = resolved(for: info)
        let dragged = state.dragged
        state.clear()
        guard let (target, landing) = resolved else { return false }

        // A drag that started in this window is already decoded: apply it now, so clearing the
        // indicator, moving the row and redrawing the list are one animated transaction. The
        // asynchronous `loadTransferable` path below is the fallback for a payload from anywhere
        // else, and is the only one that can land a frame late.
        if let dragged {
            withAnimation(Self.dropAnimation) { apply(dragged, to: target, landing: landing) }
            return true
        }

        switch (target, landing) {
        case (.folder, .into):
            return move(SnippetsSnippetDragItem.self, contentType: .clipySnippetsSnippetRow, of: info) { item in
                apply(.snippet(item.identifier), to: target, landing: landing)
            }

        case (.folder, .before), (.folder, .after):
            return move(SnippetsFolderDragItem.self, contentType: .clipySnippetsFolderRow, of: info) { item in
                apply(.folder(item.identifier), to: target, landing: landing)
            }

        case (.snippet, .before), (.snippet, .after):
            return move(SnippetsSnippetDragItem.self, contentType: .clipySnippetsSnippetRow, of: info) { item in
                apply(.snippet(item.identifier), to: target, landing: landing)
            }

        case (.snippet, .into):
            return false
        }
    }

    /// Matches the import overlay's `.easeInOut(duration: 0.12)` in `SnippetsEditorView`, a
    /// touch slower because a row travelling the height of the list needs longer to read.
    static let dropAnimation: Animation = .easeInOut(duration: 0.18)
}

// MARK: - Applying
private extension SnippetsRowDropDelegate {

    func apply(_ dragged: SnippetsDragPayload, to target: SnippetsSelection, landing: SnippetsDropIndicator) {
        switch (target, landing, dragged) {
        case let (.folder(folderIdentifier), .into, .snippet(identifier)):
            store.moveSnippet(identifier, toFolder: folderIdentifier)

        case let (.folder(folderIdentifier), .before, .folder(identifier)):
            store.moveFolder(identifier, relativeTo: folderIdentifier, position: .before)

        case let (.folder(folderIdentifier), .after, .folder(identifier)):
            store.moveFolder(identifier, relativeTo: folderIdentifier, position: .after)

        case let (.snippet(snippetIdentifier), .before, .snippet(identifier)):
            store.moveSnippet(identifier, relativeTo: snippetIdentifier, position: .before)

        case let (.snippet(snippetIdentifier), .after, .snippet(identifier)):
            store.moveSnippet(identifier, relativeTo: snippetIdentifier, position: .after)

        default:
            // Every other pairing is one `landing(for:)` already refused.
            break
        }
    }
}

// MARK: - Landing
private extension SnippetsRowDropDelegate {

    /// Publishes where the indicator goes, and returns what a drop would do.
    @discardableResult
    func update(with info: DropInfo) -> SnippetsDropIndicator? {
        guard let (target, landing) = resolved(for: info) else {
            state.clear()
            return nil
        }
        state.hover(landing, over: target, springLoad: springLoad(for: target, landing: landing))
        return landing
    }

    /// Opening a collapsed folder the pointer is holding over it, or nil when there is nothing
    /// to open: an expanded folder, or a landing that is not going inside one.
    func springLoad(for target: SnippetsSelection, landing: SnippetsDropIndicator) -> (() -> Void)? {
        guard landing == .into,
              let identifier = target.folderIdentifier,
              !store.expandedFolders.contains(identifier) else { return nil }

        return { [store] in
            withAnimation(Self.dropAnimation) { _ = store.expandedFolders.insert(identifier) }
        }
    }

    /// Which row the indicator belongs on, and what a drop would do — or nil to refuse the drag.
    ///
    /// Not necessarily *this* row: a landing on the leading edge is rewritten to the trailing
    /// edge of the row above whenever the two name the same slot (`mergedWithRowAbove`), so the
    /// gap between two rows is a single target rather than two that look identical.
    func resolved(for info: DropInfo) -> (SnippetsSelection, SnippetsDropIndicator)? {
        guard let landing = landing(for: info) else { return nil }

        if landing == .before, let above = row.mergedWithRowAbove {
            // That slot is where the dragged row already sits.
            guard !state.isDragged(above) else { return nil }
            return (above, .after)
        }
        return (row.id, landing)
    }

    /// What this row would do with the payload currently in flight, or nil if it would refuse it.
    ///
    /// The hover only knows the payload's *type*, never its value — which is exactly why folders
    /// and snippets carry separate `UTType`s.
    func landing(for info: DropInfo) -> SnippetsDropIndicator? {
        // No line under the row you are holding: the drop would be a no-op anyway.
        guard !state.isDragged(row.id) else { return nil }

        switch row.id {
        case .folder(let folderIdentifier):
            // A snippet always goes *inside* a folder: that is the only way to reach a collapsed
            // or empty one. Position within the folder is chosen by dropping on a snippet row.
            if info.hasItemsConforming(to: [.clipySnippetsSnippetRow]) {
                // Dropping a snippet on the folder it is already in is a no-op `moveSnippet`
                // refuses silently — refuse the highlight too, rather than invite a drop that
                // visibly does nothing.
                guard !isDraggedSnippetAlreadyIn(folderIdentifier) else { return nil }
                return .into
            }
            guard info.hasItemsConforming(to: [.clipySnippetsFolderRow]) else { return nil }
            return edge(for: info)

        case .snippet:
            guard info.hasItemsConforming(to: [.clipySnippetsSnippetRow]) else { return nil }
            return edge(for: info)
        }
    }

    /// `DropInfo.location` is in the coordinate space of the view the delegate is attached to,
    /// so the row's own height is all this needs.
    func edge(for info: DropInfo) -> SnippetsDropIndicator {
        guard rowHeight > 0 else { return .before }
        return info.location.y > rowHeight / 2 ? .after : .before
    }

    /// Only answerable for a same-window drag: an external payload is not decoded until the drop
    /// itself, so a drag from another window still highlights every folder as `.into` until then.
    func isDraggedSnippetAlreadyIn(_ folderIdentifier: String) -> Bool {
        guard case .snippet(let identifier) = state.dragged else { return false }
        return store.rows.first { $0.snippets.contains { $0.id == identifier } }?.id == folderIdentifier
    }

    /// Decodes the payload and applies it on the main thread. Returns true because the load is
    /// asynchronous: refusing here would animate the drag back even though the move is happening.
    func move<Item: Transferable>(_ type: Item.Type,
                                  contentType: UTType,
                                  of info: DropInfo,
                                  apply: @escaping (Item) -> Void) -> Bool {
        guard let provider = info.itemProviders(for: [contentType]).first else { return false }

        _ = provider.loadTransferable(type: type) { result in
            switch result {
            case .success(let item):
                // Not `DispatchQueue.main.async`: this completion can land while a menu or the
                // drag session itself is still running a tracking run loop, which does not drain
                // the main dispatch queue (see `MainRunLoopScheduler`).
                RunLoop.main.perform(inModes: [.common]) { withAnimation(Self.dropAnimation) { apply(item) } }
            case .failure(let error):
                lError(error)
            }
        }
        return true
    }
}
