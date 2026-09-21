//
//  SnippetImportModeTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
@testable import Clipy

/// The two things an import file can mean, at the layer where they actually differ.
///
/// `SnippetsEditorStore.confirmPendingImport(mode:)` picks between them, but everything it does
/// after the alert is a `MainScheduler` hop away, so these drive the transaction the way the store
/// composes it: `importFolders` alone for Insert, `clearAllFolders()` then `importFolders` in one
/// closure for Replace. The half only Replace can do is dropping rows the file does not mention —
/// an upsert keyed by identifier has no way to learn they exist.
final class SnippetImportModeTests: ClipDBTestCase {

    // MARK: - Fixtures

    private func makeFolder(_ identifier: String,
                            index: Int = 0,
                            title: String? = nil,
                            snippets: [String] = []) -> CPYFolder {
        let folder = CPYFolder()
        folder.identifier = identifier
        folder.index = index
        folder.title = title ?? identifier
        folder.snippets = snippets.enumerated().map { offset, snippetIdentifier in
            let snippet = CPYSnippet()
            snippet.identifier = snippetIdentifier
            snippet.index = offset
            snippet.title = snippetIdentifier
            snippet.content = snippetIdentifier
            snippet.folderIdentifier = identifier
            return snippet
        }
        return folder
    }

    /// The starting library every case below imports on top of.
    @discardableResult
    private func seed() throws -> [CPYFolder] {
        let existing = [makeFolder("old", index: 0, snippets: ["old-1", "old-2"]),
                        makeFolder("shared", index: 1, snippets: ["shared-1", "shared-kept"])]
        try performSnippet("seed") { try $0.importFolders(existing) }
        return existing
    }

    /// A file that re-states `shared` with one snippet fewer, and adds a folder of its own.
    private func importFile() -> [CPYFolder] {
        [makeFolder("shared", index: 0, title: "Shared (imported)", snippets: ["shared-1"]),
         makeFolder("new", index: 1, snippets: ["new-1"])]
    }

    private func fetched() throws -> [CPYFolder] {
        try performSnippet("fetch") { try $0.fetchFolders() }
    }

    // MARK: - clearAllFolders

    func testClearAllFoldersEmptiesBothTables() throws {
        try seed()

        try performSnippet("clear") { try $0.clearAllFolders() }

        XCTAssertEqual(try fetched().count, 0)
        // `fetchFolders()` joins through the folder rows, so it cannot see an orphan. Ask directly.
        XCTAssertNil(try performSnippet("orphan") { try $0.fetchSnippet(identifier: "old-1") })
    }

    // MARK: - Replace

    func testReplaceLeavesOnlyTheFile() throws {
        try seed()
        let imported = importFile()

        try performSnippet("replace") { transaction in
            try transaction.clearAllFolders()
            try transaction.importFolders(imported)
        }

        let folders = try fetched()
        XCTAssertEqual(folders.map { $0.identifier }, ["shared", "new"])
        XCTAssertEqual(folders.first?.title, "Shared (imported)")
        // The file's own indices, not offset past the library it replaced.
        XCTAssertEqual(folders.map { $0.index }, [0, 1])
    }

    /// The half Insert cannot do: `shared` survives by identifier, but the snippet the file no
    /// longer lists goes with the old row rather than lingering under the re-imported folder.
    func testReplaceDropsSnippetsTheFileNoLongerLists() throws {
        try seed()

        try performSnippet("replace") { transaction in
            try transaction.clearAllFolders()
            try transaction.importFolders(self.importFile())
        }

        let shared = try XCTUnwrap(try fetched().first { $0.identifier == "shared" })
        XCTAssertEqual(shared.snippets.map { $0.identifier }, ["shared-1"])
        XCTAssertNil(try performSnippet("orphan") { try $0.fetchSnippet(identifier: "shared-kept") })
    }

    // MARK: - Insert

    /// Locks the historical semantics in place: nothing existing is removed, same identifiers are
    /// overwritten, and a folder the file does not mention is untouched.
    func testInsertKeepsEverythingThatWasAlreadyThere() throws {
        try seed()

        try performSnippet("insert") { try $0.importFolders(self.importFile()) }

        let folders = try fetched()
        XCTAssertEqual(Set(folders.map { $0.identifier }), ["old", "shared", "new"])
        XCTAssertEqual(folders.first { $0.identifier == "old" }?.snippets.count, 2)
        XCTAssertEqual(folders.first { $0.identifier == "shared" }?.title, "Shared (imported)")
        // Still there precisely because an upsert never learns the file dropped it.
        XCTAssertNotNil(try performSnippet("kept") { try $0.fetchSnippet(identifier: "shared-kept") })
    }
}
