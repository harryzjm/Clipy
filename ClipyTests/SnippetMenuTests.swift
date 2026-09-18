//
//  SnippetMenuTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
@testable import Clipy

/// Covers `SnippetMenu`'s shape.
///
/// The menu is now a pure function of `([CPYFolder], SnippetMenuConfig)` — no database, no
/// `AppEnvironment` — which is what makes these assertions possible at all. The config is
/// injected rather than read from defaults because the test target never runs
/// `CPYUtilities.registerUserDefaultKeys()`, so every `bool(forKey:)` would read `false`.
final class SnippetMenuTests: XCTestCase {

    private let plain = SnippetMenuConfig(isMarkWithNumber: false, showIconInTheMenu: false)

    // MARK: - Header

    /// No folders at all leaves a completely empty menu — not even the header.
    func testNoFoldersProducesEmptyMenu() {
        let menu = SnippetMenu(title: "test", folders: [], config: plain)

        XCTAssertEqual(menu.numberOfItems, 0)
    }

    /// Folders that are all disabled still get the header. This is the case the `isEmpty` guard
    /// is deliberately placed *before* the `enable` filter for, and the easiest one to lose.
    func testAllDisabledFoldersProducesHeaderOnly() {
        let menu = SnippetMenu(title: "test", folders: [folder("a", enable: false)], config: plain)

        XCTAssertEqual(menu.numberOfItems, 1)
        XCTAssertNil(menu.item(at: 0)?.submenu)
    }

    // MARK: - Structure

    /// One submenu per enabled folder, disabled folders skipped.
    func testOneSubmenuPerEnabledFolder() {
        let menu = SnippetMenu(title: "test",
                               folders: [folder("kept"), folder("dropped", enable: false), folder("also kept")],
                               config: plain)

        let folderTitles = menu.items.dropFirst().map { $0.title }
        XCTAssertEqual(folderTitles, ["kept", "also kept"])
    }

    /// Disabled snippets never reach the menu.
    func testDisabledSnippetsAreExcluded() {
        let menu = SnippetMenu(title: "test",
                               folders: [folder("f", snippets: [snippet("yes"), snippet("no", enable: false)])],
                               config: plain)

        XCTAssertEqual(submenuTitles(menu, at: 1), ["yes"])
    }

    /// Numbering restarts inside every folder rather than running on across them.
    func testNumberingRestartsPerFolder() {
        let config = SnippetMenuConfig(isMarkWithNumber: true, showIconInTheMenu: false)
        let menu = SnippetMenu(title: "test",
                               folders: [folder("first", snippets: [snippet("a"), snippet("b")]),
                                         folder("second", snippets: [snippet("c")])],
                               config: config)

        XCTAssertEqual(submenuTitles(menu, at: 1), ["1. a", "2. b"])
        XCTAssertEqual(submenuTitles(menu, at: 2), ["1. c"])
    }

    /// The identifier is all a menu item carries; `AppDelegate.selectSnippetMenuItem(_:)` reads
    /// the snippet back out of the database with it once the menu has closed.
    func testItemCarriesSnippetIdentifier() {
        let target = snippet("a")
        let menu = SnippetMenu(title: "test", folders: [folder("f", snippets: [target])], config: plain)

        let item = menu.item(at: 1)?.submenu?.item(at: 0)
        XCTAssertEqual(item?.representedObject as? String, target.identifier)
        XCTAssertEqual(item?.action, #selector(AppDelegate.selectSnippetMenuItem(_:)))
    }

    // MARK: - Config

    /// Both preferences are honoured, and neither is applied when off.
    func testConfigDrivesNumberingAndIcons() {
        let folders = [folder("f", snippets: [snippet("a")])]

        let off = SnippetMenu(title: "test", folders: folders, config: plain)
        XCTAssertEqual(submenuTitles(off, at: 1), ["a"])
        XCTAssertNil(off.item(at: 1)?.image)
        XCTAssertNil(off.item(at: 1)?.submenu?.item(at: 0)?.image)

        let on = SnippetMenu(title: "test",
                             folders: folders,
                             config: SnippetMenuConfig(isMarkWithNumber: true, showIconInTheMenu: true))
        XCTAssertEqual(submenuTitles(on, at: 1), ["1. a"])
        XCTAssertEqual(on.item(at: 1)?.image, MenuIcon.folder)
        XCTAssertEqual(on.item(at: 1)?.submenu?.item(at: 0)?.image, MenuIcon.snippet)
    }

    /// A multi-line snippet title is cut down to its first line, then ellipsised.
    func testTitleIsFirstLineAndTruncated() {
        let folders = [folder("f", snippets: [snippet("  first line\nsecond line"),
                                              snippet(String(repeating: "x", count: 30))])]
        let menu = SnippetMenu(title: "test", folders: folders, config: plain)

        XCTAssertEqual(submenuTitles(menu, at: 1),
                       ["first line", String(repeating: "x", count: 17) + "..."])
    }

    // MARK: - Single folder

    /// The folder-hotkey menu puts the snippets inline under the folder's own title.
    func testFolderMenuIsInline() {
        let menu = SnippetMenu(folder: folder("f", snippets: [snippet("a"), snippet("b", enable: false)]),
                               config: plain)

        XCTAssertEqual(menu.items.map { $0.title }, ["f", "a"])
        XCTAssertNil(menu.item(at: 1)?.submenu)
    }
}

// MARK: - Fixtures
private extension SnippetMenuTests {

    func folder(_ title: String, enable: Bool = true, snippets: [CPYSnippet] = []) -> CPYFolder {
        let folder = CPYFolder()
        folder.title = title
        folder.enable = enable
        folder.snippets = snippets
        return folder
    }

    func snippet(_ title: String, enable: Bool = true) -> CPYSnippet {
        let snippet = CPYSnippet()
        snippet.title = title
        snippet.enable = enable
        return snippet
    }

    func submenuTitles(_ menu: NSMenu, at index: Int) -> [String] {
        menu.item(at: index)?.submenu?.items.map { $0.title } ?? []
    }
}
