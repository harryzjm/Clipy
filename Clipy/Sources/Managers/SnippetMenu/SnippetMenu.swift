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
final class SnippetMenu: NSMenu {

    /// Snippet numbering restarts here inside every folder; it is not continuous across them.
    fileprivate static let firstListNumber = 1

    fileprivate let config: SnippetMenuConfig

    /// The whole graph: a disabled header, then one submenu per enabled folder.
    init(title: String, folders: [CPYFolder], config: SnippetMenuConfig = .current()) {
        self.config = config
        super.init(title: title)
        addFolderItems(folders)
    }

    /// A single folder, behind its own hotkey: the folder title as a disabled header, then that
    /// folder's enabled snippets inline.
    init(folder: CPYFolder, config: SnippetMenuConfig = .current()) {
        self.config = config
        super.init(title: folder.title)
        addItem(SnippetMenu.headerItem(folder.title))
        addSnippetItems(folder.snippets, to: self)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    func addFolderItems(_ folders: [CPYFolder]) {
        // Tested before the `enable` filter, deliberately: no folders at all leaves a completely
        // empty menu, while folders that are all disabled still get the header.
        guard !folders.isEmpty else { return }

        addItem(SnippetMenu.headerItem(L10n.Menu.snippetHeader))

        folders
            .filter { $0.enable }
            .forEach { folder in
                let item = folderItem(folder.title)
                addItem(item)
                addSnippetItems(folder.snippets, to: item.submenu)
            }
    }

    func addSnippetItems(_ snippets: [CPYSnippet], to menu: NSMenu?) {
        guard let menu = menu else { return }

        var listNumber = SnippetMenu.firstListNumber
        snippets
            .filter { $0.enable }
            .forEach { snippet in
                menu.addItem(snippetItem(snippet, listNumber: listNumber))
                listNumber += 1
            }
    }

    static func headerItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil)
        item.isEnabled = false
        return item
    }

    func folderItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil)
        item.submenu = NSMenu(title: "")
        item.image = config.showIconInTheMenu ? MenuIcon.folder : nil
        return item
    }

    func snippetItem(_ snippet: CPYSnippet, listNumber: Int) -> NSMenuItem {
        let title = snippet.title.snippetMenuTitle
        let item = NSMenuItem(title: config.isMarkWithNumber ? "\(listNumber). \(title)" : title,
                              action: #selector(AppDelegate.selectSnippetMenuItem(_:)),
                              keyEquivalent: "")
        item.representedObject = snippet.identifier
        item.toolTip = snippet.content
        item.image = config.showIconInTheMenu ? MenuIcon.snippet : nil
        return item
    }
}

// MARK: - Extension
private let shortenSymbol = "..."
private let maxTitleLength = 20

fileprivate extension String {

    /// The first line only, whitespace-trimmed and ellipsised.
    var snippetMenuTitle: String {
        let theString = trimmingCharacters(in: .whitespacesAndNewlines) as NSString

        let aRange = NSRange(location: 0, length: 0)
        var lineStart = 0, lineEnd = 0, contentsEnd = 0
        theString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: aRange)

        var titleString = (lineEnd == theString.length) ? theString as String : theString.substring(to: contentsEnd)

        if titleString.utf16.count > maxTitleLength {
            titleString = (titleString as NSString).substring(to: maxTitleLength - shortenSymbol.count) + shortenSymbol
        }

        return titleString
    }
}
