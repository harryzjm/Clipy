//
//  SnippetsSidebar.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI
import UniformTypeIdentifiers

/// The folder/snippet tree, replacing the `NSOutlineView` and its data source and delegate.
///
/// Reordering is the rows' own drag and drop (`.onDrag` + `SnippetsRowDropDelegate`), not
/// `ForEach.onMove`: the built-in reorder is started by the AppKit table row, which never sees
/// the mouse-down while the pointer is over a row's `Text` or icon, so it only ever worked from
/// the empty stretch at the end of a row — and it cannot express a cross-folder move at all.
///
/// **One flat `ForEach`, not nested `DisclosureGroup`s.** The tree shape was the obvious
/// spelling and is why cross-folder drops could not animate: with a `ForEach` per folder, moving
/// a snippet between folders is a delete in one container and an insert in another, and `List`
/// reloads instead of animating. Flattened, every move — within a folder or across two — is one
/// container reordering itself, which is exactly the case SwiftUI animates. The disclosure
/// triangle is drawn here rather than by `DisclosureGroup`, which costs a chevron and an indent
/// and buys back the expansion state the editor has to drive programmatically anyway (after
/// adding a snippet, and after moving one into a collapsed folder).
struct SnippetsSidebar: View {

    @Bindable var store: SnippetsEditorStore

    /// Lives as long as the sidebar, but only ever holds something mid-drag.
    @State private var dropState = SnippetsDropState()

    var body: some View {
        List(selection: $store.selection) {
            ForEach(rows) { row in
                SnippetsSidebarRow(row: row, store: store, dropState: dropState)
                    .tag(row.id)
            }
        }
        .listStyle(.sidebar)
        // The rows measure themselves in here, so an insertion line can sit in the middle of the
        // gap between two of them instead of against one's edge.
        .coordinateSpace(name: SnippetsDropState.coordinateSpace)
    }

    private var rows: [SnippetsSidebarItem] {
        SnippetsSidebarItem.rows(for: store.rows, expanded: store.expandedFolders)
    }
}

/// One line of the flattened tree.
struct SnippetsSidebarItem: Identifiable, Hashable {

    let id: SnippetsSelection
    let title: String
    /// The item's own flag: what the context menu's Enable/Disable item toggles.
    let isEnabled: Bool
    /// What the row draws with. Identical for a folder; for a snippet it also folds in the owning
    /// folder's flag, because a disabled folder takes its whole submenu out of `SnippetMenu`.
    let isEffectivelyEnabled: Bool
    /// nil for a folder; the owning folder for a snippet.
    let parentIdentifier: String?
    /// nil for a snippet, so only folders draw a chevron.
    let isExpanded: Bool?

    /// The row above, when dropping *after* it and *before* this one are the same insertion
    /// point — two snippets of one folder, or two folder headers. The gap between them is then
    /// a single target, addressed as the upper row's trailing edge, so crossing the boundary
    /// mid-drag does not swap one indicator for an identical-looking other.
    ///
    /// nil where the two sides genuinely differ: the gap between a folder's last snippet and the
    /// next folder's header is "append to this folder" above and "into the next folder" below,
    /// and merging them would make one of the two unreachable.
    fileprivate(set) var mergedWithRowAbove: SnippetsSelection?

    /// The rows either side, for measuring the gap an insertion line has to sit in the middle of.
    fileprivate(set) var rowAbove: SnippetsSelection?
    fileprivate(set) var rowBelow: SnippetsSelection?

    var isFolder: Bool { parentIdentifier == nil }

    init(folder: FolderRow, isExpanded: Bool) {
        id = .folder(folder.id)
        title = folder.title
        isEnabled = folder.enable
        isEffectivelyEnabled = folder.enable
        parentIdentifier = nil
        self.isExpanded = isExpanded
    }

    init(snippet: SnippetRow, parentIdentifier: String) {
        id = .snippet(snippet.id)
        title = snippet.title
        isEnabled = snippet.enable
        isEffectivelyEnabled = snippet.isEffectivelyEnabled
        self.parentIdentifier = parentIdentifier
        isExpanded = nil
    }

    /// Folders in order, each followed by its snippets when it is expanded.
    static func rows(for folders: [FolderRow], expanded: Set<String>) -> [SnippetsSidebarItem] {
        var rows: [SnippetsSidebarItem] = []
        for folder in folders {
            let isExpanded = expanded.contains(folder.id)
            rows.append(SnippetsSidebarItem(folder: folder, isExpanded: isExpanded))
            guard isExpanded else { continue }
            rows.append(contentsOf: folder.snippets.map { SnippetsSidebarItem(snippet: $0, parentIdentifier: folder.id) })
        }

        for index in rows.indices {
            if index > rows.startIndex {
                rows[index].rowAbove = rows[index - 1].id
                if rows[index].isEquivalentTarget(to: rows[index - 1]) {
                    rows[index].mergedWithRowAbove = rows[index - 1].id
                }
            }
            if index < rows.index(before: rows.endIndex) {
                rows[index].rowBelow = rows[index + 1].id
            }
        }
        return rows
    }

    /// Same kind, same container — the two conditions under which "after that row" and "before
    /// this one" name the same slot.
    private func isEquivalentTarget(to other: SnippetsSidebarItem) -> Bool {
        isFolder ? other.isFolder : parentIdentifier == other.parentIdentifier
    }
}

private struct SnippetsSidebarRow: View {

    let row: SnippetsSidebarItem

    @Bindable var store: SnippetsEditorStore
    let dropState: SnippetsDropState

    @State private var draft = ""
    /// Measured, not assumed: the drop delegate splits the row in half to pick before / after.
    @State private var rowHeight: CGFloat = 0
    @FocusState private var isFocused: Bool

    private static let insertionLineHeight: CGFloat = 2

    /// Half the gap to the neighbouring row, which puts the line's centre on the gap's centre.
    /// Falls back to half the line's own height — the neighbour is off screen or not laid out
    /// yet, and straddling this row's edge is the closest thing to the middle available.
    private func gapOffset(towards neighbour: SnippetsSelection?) -> CGFloat {
        guard let neighbour, let gap = dropState.gap(between: selection, and: neighbour) else {
            return Self.insertionLineHeight / 2
        }
        return gap / 2
    }

    private var title: String { row.title }
    private var isFolder: Bool { row.isFolder }
    private var isEnabled: Bool { row.isEnabled }
    private var isEffectivelyEnabled: Bool { row.isEffectivelyEnabled }
    private var selection: SnippetsSelection { row.id }
    private var parentIdentifier: String? { row.parentIdentifier }

    /// Read from the shared state rather than stored here: see `SnippetsDropState`.
    private var dropIndicator: SnippetsDropIndicator? { dropState.indicator(for: selection) }

    var body: some View {
        content
            .font(.system(size: 14))
            .contextMenu { menu }
    }

    @ViewBuilder
    private var content: some View {
        if store.renamingID == selection {
            TextField("", text: $draft)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onAppear {
                    draft = title
                    isFocused = true
                }
                .onSubmit { store.commitRename(draft) }
                .onChange(of: isFocused) { _, focused in
                    guard !focused, store.renamingID == selection else { return }
                    store.commitRename(draft)
                }
                .onExitCommand { store.renamingID = nil }
        } else {
            draggableLabel
                .simultaneousGesture(TapGesture(count: 2).onEnded { beginRename() })
                .simultaneousGesture(TapGesture(count: 1).onEnded { store.selection = selection })
                .onDrop(of: [.clipySnippetsFolderRow, .clipySnippetsSnippetRow],
                        delegate: SnippetsRowDropDelegate(row: row,
                                                          rowHeight: rowHeight,
                                                          store: store,
                                                          state: dropState))
                // Keyboard equivalent of the disclosure chevron's tap, for a folder row that is
                // the current selection — the outline view this replaced expanded/collapsed on
                // the arrow keys, and `DisclosureGroup` would have given that back for free.
                // `.ignored` on every other key, row and direction so this never steals input
                // `List` itself would otherwise handle (up/down selection movement, for one).
                .onKeyPress(.rightArrow) { handleDisclosureKey(expand: true) }
                .onKeyPress(.leftArrow) { handleDisclosureKey(expand: false) }
        }
    }

    private func handleDisclosureKey(expand: Bool) -> KeyPress.Result {
        guard let isExpanded = row.isExpanded, store.selection == selection, isExpanded != expand else { return .ignored }
        toggleExpansion(to: expand)
        return .handled
    }

    private var label: some View {
        HStack(spacing: 4) {
            disclosure
            if isFolder {
                SwiftUI.Image(systemName: "folder.fill")
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .foregroundStyle(titleColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Before `contentShape`, so the hit area grows with it: `List` puts its own padding
        // around row content, and a drop landing in that gap belongs to no row at all.
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .background { rowHeightReader }
        .background { dropHighlight }
        .overlay(alignment: .top) { insertionLine(.before) }
        .overlay(alignment: .bottom) { insertionLine(.after) }
        .animation(.easeOut(duration: 0.12), value: dropIndicator)
    }

    /// `.onDrag` rather than `.draggable`, which is otherwise the modern spelling of the same
    /// thing: `.draggable` puts its drag in the same SwiftUI gesture arena as the two taps below
    /// and loses to them, so a row with click-to-select and double-click-to-rename never starts
    /// a drag at all. `.onDrag` registers an AppKit dragging source instead and coexists with
    /// them. Verified by bisecting the two APIs against the gestures in a running build.
    ///
    /// Folders and snippets carry separate payload types so that a row can tell, during the
    /// hover, whether it is a legal target — `DropInfo` answers which types are in flight, never
    /// which values.
    private var draggableLabel: some View {
        label.onDrag({ itemProvider() }, preview: { dragPreview })
    }

    /// The payload is the same JSON `CodableRepresentation` the `Transferable` conformances
    /// declare, so the drop side can still decode it with `loadTransferable`.
    private func itemProvider() -> NSItemProvider {
        // `begin` also clears whatever the previous drag left behind, so every drag starts clean.
        let data: Data?
        let contentType: UTType
        if isFolder {
            let identifier = selection.folderIdentifier ?? ""
            contentType = .clipySnippetsFolderRow
            data = try? JSONEncoder().encode(SnippetsFolderDragItem(identifier: identifier))
            dropState.begin(.folder(identifier))
        } else {
            let identifier = selection.snippetIdentifier ?? ""
            contentType = .clipySnippetsSnippetRow
            data = try? JSONEncoder().encode(SnippetsSnippetDragItem(identifier: identifier))
            dropState.begin(.snippet(identifier))
        }
        return NSItemProvider(item: data as NSData?, typeIdentifier: contentType.identifier)
    }

    /// The default snapshot of a `maxWidth: .infinity` row drags a full-width slab around.
    private var dragPreview: some View {
        HStack(spacing: 4) {
            SwiftUI.Image(systemName: isFolder ? "folder.fill" : "note.text")
            Text(title)
        }
        .padding(4)
    }

    /// The chevron `DisclosureGroup` used to draw, plus the indent it used to apply. A snippet
    /// gets the same width as a spacer so both kinds of row line their titles up with each other.
    @ViewBuilder
    private var disclosure: some View {
        if let isExpanded = row.isExpanded {
            // A real `Button` rather than `.onTapGesture` on an `Image`: that gave the chevron a
            // click target but nothing a keyboard or VoiceOver user could act on at all.
            Button {
                toggleExpansion(to: !isExpanded)
            } label: {
                SwiftUI.Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? L10n.Snippets.Sidebar.Accessibility.collapse
                                            : L10n.Snippets.Sidebar.Accessibility.expand)
        } else {
            SwiftUI.Color.clear
                .frame(width: 20, height: 1)
        }
    }

    private func toggleExpansion(to isExpanded: Bool) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if isExpanded {
                store.expandedFolders.insert(row.id.folderIdentifier ?? "")
            } else {
                store.expandedFolders.remove(row.id.folderIdentifier ?? "")
            }
        }
    }

    private var rowHeightReader: some View {
        GeometryReader { proxy in
            SwiftUI.Color.clear
                .onAppear { measure(proxy) }
                .onChange(of: proxy.frame(in: .named(SnippetsDropState.coordinateSpace))) { _, _ in measure(proxy) }
        }
    }

    private func measure(_ proxy: GeometryProxy) {
        rowHeight = proxy.size.height
        dropState.record(proxy.frame(in: .named(SnippetsDropState.coordinateSpace)), for: selection)
    }

    @ViewBuilder
    private var dropHighlight: some View {
        if dropIndicator == .into {
            RoundedRectangle(cornerRadius: 4)
                .fill(SwiftUI.Color.accentColor.opacity(0.18))
        }
    }

    @ViewBuilder
    private func insertionLine(_ edge: SnippetsDropIndicator) -> some View {
        if dropIndicator == edge {
            Rectangle()
                .fill(SwiftUI.Color.accentColor)
                .frame(height: Self.insertionLineHeight)
                // Into the gap, not against this row's edge: `List` insets each row's content,
                // so the space a reader sees between two rows is outside both of them and a
                // line drawn at an edge reads as belonging to that row rather than to the slot.
                // The offset is measured rather than assumed — the inset is the list style's.
                .offset(y: edge == .after ? gapOffset(towards: row.rowBelow) : -gapOffset(towards: row.rowAbove))
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button(L10n.Snippets.Sidebar.ContextMenu.rename) { beginRename() }
        Button(isEnabled ? L10n.Snippets.Sidebar.ContextMenu.disable : L10n.Snippets.Sidebar.ContextMenu.enable) {
            store.selection = selection
            store.toggleEnabled()
        }
        if let snippetIdentifier = selection.snippetIdentifier, otherFolders.isEmpty == false {
            Menu(L10n.Snippets.Sidebar.ContextMenu.moveToFolder) {
                ForEach(otherFolders) { folder in
                    Button(folder.title) {
                        store.moveSnippet(snippetIdentifier, toFolder: folder.id)
                    }
                }
            }
        }
        Divider()
        Button(L10n.Snippets.Sidebar.ContextMenu.delete, role: .destructive) {
            store.selection = selection
            store.isDeleteConfirmationPresented = true
        }
    }

    private var otherFolders: [FolderRow] {
        store.rows.filter { $0.id != parentIdentifier }
    }

    private var titleColor: SwiftUI.Color {
        isEffectivelyEnabled ? .primary : SwiftUI.Color(nsColor: .disabledControlTextColor)
    }

    private var iconColor: SwiftUI.Color {
        isEffectivelyEnabled ? .secondary : SwiftUI.Color(nsColor: .disabledControlTextColor)
    }

    private func beginRename() {
        store.selection = selection
        store.renamingID = selection
    }
}
