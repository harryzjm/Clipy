//
//  SnippetsSidebarItemTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import XCTest
@testable import Clipy

/// The flattened tree the sidebar renders, and the gap merging that rides on it.
///
/// Flat is what makes a cross-folder drop an animatable move instead of a delete plus an insert
/// in two different containers, so the shape of this list is load-bearing for more than layout.
final class SnippetsSidebarItemTests: XCTestCase {

    func testACollapsedFolderContributesOnlyItsHeader() {
        let rows = SnippetsSidebarItem.rows(for: [folder("f", snippets: ["a", "b"])], expanded: [])

        XCTAssertEqual(rows.map(\.id), [.folder("f")])
    }

    func testAnExpandedFolderIsFollowedByItsSnippets() {
        let rows = SnippetsSidebarItem.rows(for: [folder("f", snippets: ["a", "b"])], expanded: ["f"])

        XCTAssertEqual(rows.map(\.id), [.folder("f"), .snippet("a"), .snippet("b")])
    }

    func testFoldersKeepTheirOrder() {
        let rows = SnippetsSidebarItem.rows(for: [folder("f1", snippets: ["a"]), folder("f2", snippets: ["b"])],
                                            expanded: ["f2"])

        XCTAssertEqual(rows.map(\.id), [.folder("f1"), .folder("f2"), .snippet("b")])
    }

    // MARK: - Gap merging

    /// Two snippets of one folder: "after the first" and "before the second" are one slot, so the
    /// second row hands its leading edge to the first.
    func testSnippetsOfOneFolderShareTheGapBetweenThem() {
        let rows = SnippetsSidebarItem.rows(for: [folder("f", snippets: ["a", "b"])], expanded: ["f"])

        XCTAssertEqual(rows[2].mergedWithRowAbove, .snippet("a"))
    }

    /// The gap under a folder header is "into the folder, at the top" and nothing else: merging
    /// it into the header would be merging two different meanings.
    func testAFolderHeaderDoesNotSwallowTheGapAboveItsFirstSnippet() {
        let rows = SnippetsSidebarItem.rows(for: [folder("f", snippets: ["a"])], expanded: ["f"])

        XCTAssertNil(rows[1].mergedWithRowAbove)
    }

    func testTwoFolderHeadersShareTheGapBetweenThem() {
        let rows = SnippetsSidebarItem.rows(for: [folder("f1", snippets: []), folder("f2", snippets: [])],
                                            expanded: [])

        XCTAssertEqual(rows[1].mergedWithRowAbove, .folder("f1"))
    }

    /// Above the header sits the previous folder's last snippet: "append to that folder" versus
    /// "into this one", which are different slots and must stay separately reachable.
    func testAFolderHeaderDoesNotMergeWithTheSnippetAboveIt() {
        let rows = SnippetsSidebarItem.rows(for: [folder("f1", snippets: ["a"]), folder("f2", snippets: [])],
                                            expanded: ["f1"])

        XCTAssertEqual(rows.map(\.id), [.folder("f1"), .snippet("a"), .folder("f2")])
        XCTAssertNil(rows[2].mergedWithRowAbove)
    }

    func testTheFirstRowHasNothingToMergeWith() {
        let rows = SnippetsSidebarItem.rows(for: [folder("f", snippets: [])], expanded: [])

        XCTAssertNil(rows[0].mergedWithRowAbove)
    }
}

// MARK: - Fixtures
private extension SnippetsSidebarItemTests {

    func folder(_ identifier: String, snippets: [String]) -> FolderRow {
        let folder = CPYFolder()
        folder.identifier = identifier
        folder.title = identifier
        folder.snippets = snippets.map { identifier -> CPYSnippet in
            let snippet = CPYSnippet()
            snippet.identifier = identifier
            snippet.title = identifier
            return snippet
        }
        return FolderRow(folder: folder)
    }
}
