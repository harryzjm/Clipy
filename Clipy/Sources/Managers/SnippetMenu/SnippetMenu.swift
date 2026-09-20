//
//  SnippetMenu.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Cocoa
import RxSwift

/// The snippets menu, built fresh on every popup.
///
/// Nothing retains it: `popUp(positioning:at:in:)` runs a nested tracking loop and AppKit holds
/// the menu for its duration. The items outliving it is not a problem either — each carries only
/// `snippet.identifier`, and `AppDelegate.selectSnippetMenuItem(_:)` re-reads the snippet from
/// the database once the menu has closed.
///
/// It does hold the folder graph it was built from, because the search field re-filters it on
/// every keystroke. The snippet database has no live-observation path and no fts index; the
/// graph is read once, in `build(box:)`, and every filter after that is pure in-memory work.
final class SnippetMenu: NSMenu, FilterableMenu {

    /// Snippet numbering restarts here inside every folder; it is not continuous across them.
    /// A filtered list has no folders to restart in, so there it runs straight through.
    fileprivate static let firstListNumber = 1

    /// Between the folder name and the snippet title on a filtered row.
    fileprivate static let folderSeparator = " / "

    fileprivate let config: SnippetMenuConfig
    fileprivate let folders: [CPYFolder]

    /// False for the folder-hotkey menu, which is already one folder deep: it lays its snippets
    /// out inline and a filtered row there has no folder name worth repeating.
    fileprivate let showsFolderSubmenus: Bool

    /// Doubles as the header — the label it draws is the title the disabled header item used to
    /// carry, and the query field only appears once something is typed. Nil when there is
    /// nothing to search.
    fileprivate let searchItem: TextFieldMenuItem?

    fileprivate var query = ""

    /// The whole graph: the search field, then one submenu per enabled folder.
    init(title: String, folders: [CPYFolder], config: SnippetMenuConfig = .current()) {
        self.config = config
        self.folders = folders
        showsFolderSubmenus = true
        // Tested before the `enable` filter, deliberately: no folders at all leaves a completely
        // empty menu — not even a search field — while folders that are all disabled still get
        // the header.
        searchItem = folders.isEmpty ? nil : TextFieldMenuItem(title: L10n.Menu.snippetHeader, action: nil)
        super.init(title: title)
        rebuild()
    }

    /// A single folder, behind its own hotkey: the folder title as the search field's label, then
    /// that folder's enabled snippets inline.
    init(folder: CPYFolder, config: SnippetMenuConfig = .current()) {
        self.config = config
        folders = [folder]
        showsFolderSubmenus = false
        searchItem = TextFieldMenuItem(title: folder.title, action: nil)
        super.init(title: folder.title)
        rebuild()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - FilterableMenu

    func update(filter: String) {
        let new = filter.trim
        guard new != query else { return }
        query = new

        // Swapping `items` out from under a highlighted item misbehaves, so the highlight is
        // cleared first and put back on the new first row afterwards — but only when there is a
        // query: with none, row 1 is a folder, and highlighting it would spring its submenu open
        // for no reason.
        highlight(menuItem: nil)
        rebuild()
        if query.isNotEmpty, numberOfItems > 1 {
            highlight(menuItem: item(at: 1))
        }
    }
}

// MARK: - Fetch
extension SnippetMenu {

    /// Reads the snippet graph off the snippet queue, then builds the menu on the main thread.
    ///
    /// `MainRunLoopScheduler` rather than `MainScheduler`: the main dispatch queue is not drained
    /// while a menu is tracking, so a popup delivered through `MainScheduler` would only land
    /// once that menu closed. The `map` has to sit after the hop — `NSMenu` is main thread only.
    static func build(box: ClipyBox) -> Observable<SnippetMenu> {
        box
            .snippetTransaction(userInteractive: true) { try $0.fetchFolders() }
            .observe(on: MainRunLoopScheduler.instance)
            .map { SnippetMenu(title: Constants.Menu.snippet, folders: $0) }
    }
}

// MARK: - NSMenuItem
fileprivate extension SnippetMenu {

    func rebuild() {
        guard let searchItem = searchItem else { return }

        var new = query.isEmpty ? unfilteredItems() : filteredItems(SnippetFilter(query: query))
        new.insert(searchItem, at: 0)
        items = new
    }

    /// The folder graph as it stands: one submenu per enabled folder, or — under a folder
    /// hotkey — that folder's snippets inline.
    func unfilteredItems() -> [NSMenuItem] {
        guard showsFolderSubmenus else {
            return numberedItems(activeFolders.flatMap { enabledSnippets(of: $0) })
        }

        return activeFolders
            .map { folder in
                let item = folderItem(folder.title)
                numberedItems(enabledSnippets(of: folder))
                    .forEach { item.submenu?.addItem($0) }
                return item
            }
    }

    /// Every hit, flattened into one list in folder order.
    ///
    /// A folder whose own title matches counts as a match for everything inside it — that is how
    /// a folder name works as a way to narrow the list down to it.
    func filteredItems(_ filter: SnippetFilter) -> [NSMenuItem] {
        let snippets = activeFolders
            .flatMap { folder -> [(CPYSnippet, CPYFolder)] in
                // Only when the folder name is actually on the row: under a folder hotkey it is
                // not, and matching an invisible name would silently list everything.
                let matchesFolder = showsFolderSubmenus && filter.matches(folder.title)
                return enabledSnippets(of: folder)
                    .filter { matchesFolder || filter.matches($0.displayTitle) }
                    .map { ($0, folder) }
            }

        return snippets.enumerated().map { offset, pair in
            snippetItem(pair.0,
                        folder: showsFolderSubmenus ? pair.1 : nil,
                        listNumber: offset + SnippetMenu.firstListNumber,
                        filter: filter)
        }
    }

    /// Unfiltered rows: numbering restarts at 1 in each list, and no folder name is repeated
    /// on a row that already sits inside that folder's submenu.
    func numberedItems(_ snippets: [CPYSnippet]) -> [NSMenuItem] {
        snippets.enumerated().map { offset, snippet in
            snippetItem(snippet,
                        folder: nil,
                        listNumber: offset + SnippetMenu.firstListNumber,
                        filter: nil)
        }
    }

    /// The folder-hotkey menu keeps its one folder whatever its `enable` flag says — the user
    /// asked for that folder by name. In the full menu a disabled folder is hidden.
    var activeFolders: [CPYFolder] {
        showsFolderSubmenus ? folders.filter { $0.enable } : folders
    }

    func enabledSnippets(of folder: CPYFolder) -> [CPYSnippet] {
        folder.snippets.filter { $0.enable }
    }

    func folderItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil)
        item.submenu = NSMenu(title: "")
        item.image = config.showIconInTheMenu ? MenuIcon.folder : nil
        return item
    }

    func snippetItem(_ snippet: CPYSnippet, folder: CPYFolder?, listNumber: Int, filter: SnippetFilter?) -> NSMenuItem {
        // `displayTitle`, not `title`: a snippet the user never named has an empty one, and
        // takes its title from the first line of its body instead. Matching runs against the
        // same string, so what the menu shows is what the query searches.
        let body = snippet.displayTitle.snippetMenuTitle
        let searchable = folder.map { $0.title.snippetMenuTitle + SnippetMenu.folderSeparator + body } ?? body
        let prefix = config.isMarkWithNumber ? "\(listNumber). " : ""

        let item = NSMenuItem(title: prefix + searchable,
                              action: #selector(AppDelegate.selectSnippetMenuItem(_:)),
                              keyEquivalent: "")
        if let filter = filter {
            // Only while filtering: with no query there is nothing to mark, and a plain title
            // draws in the menu's own font rather than one this menu has to pick.
            item.attributedTitle = attributedTitle(prefix: prefix, searchable: searchable, filter: filter)
        }
        item.representedObject = snippet.identifier
        item.toolTip = snippet.content
        item.image = config.showIconInTheMenu ? MenuIcon.snippet : nil
        return item
    }

    /// The number prefix is kept out of `searchable` so a numeric query cannot light up the
    /// numbering it never matched.
    func attributedTitle(prefix: String, searchable: String, filter: SnippetFilter) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: config.menuFontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: font
        ]
        let keyAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.red,
            .font: font
        ]

        let body = NSMutableAttributedString(string: searchable, attributes: attributes)
        for range in filter.highlightRanges(in: searchable) {
            body.addAttributes(keyAttributes, range: NSRange(range, in: searchable))
        }

        let title = NSMutableAttributedString(string: prefix, attributes: attributes)
        title.append(body)
        return title
    }
}

// MARK: - Extension
private let shortenSymbol = "..."
private let maxTitleLength = 20

fileprivate extension String {

    /// The first line only, whitespace-trimmed and ellipsised.
    var snippetMenuTitle: String {
        let titleString = firstLine
        guard titleString.utf16.count > maxTitleLength else { return titleString }
        return (titleString as NSString).substring(to: maxTitleLength - shortenSymbol.count) + shortenSymbol
    }
}
