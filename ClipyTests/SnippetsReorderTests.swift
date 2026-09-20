//
//  SnippetsReorderTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import XCTest
@testable import Clipy

/// The index math behind the sidebar's drag and drop.
///
/// The view side cannot be exercised here — a drop is a pointer position over an `NSTableView`
/// row — so these drive the store entry points the `DropDelegate` calls, which is where the
/// off-by-ones live. Every case also asserts what came back out of the database, because the
/// in-memory array and the `index` columns are renumbered by two different code paths and only
/// the second one survives closing the window (`reload()` re-reads `fetchFolders()`).
///
/// The graph is built through `addFolder()` / `addSnippet()` rather than `reload()`: those
/// publish synchronously, so no test here has to wait on the `MainScheduler` hop.
final class SnippetsReorderTests: ClipDBTestCase {

    private var store: SnippetsEditorStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        store = SnippetsEditorStore(box: box)
    }

    override func tearDownWithError() throws {
        store = nil
        try super.tearDownWithError()
    }

    // MARK: - Folders

    func testMovingAFolderBeforeALaterOne() throws {
        let folders = makeFolders(3)

        store.moveFolder(folders[0], relativeTo: folders[2], position: .before)

        XCTAssertEqual(store.rows.map(\.id), [folders[1], folders[0], folders[2]])
        try assertPersistedFolders([folders[1], folders[0], folders[2]])
    }

    func testMovingAFolderAfterALaterOne() throws {
        let folders = makeFolders(3)

        store.moveFolder(folders[0], relativeTo: folders[2], position: .after)

        XCTAssertEqual(store.rows.map(\.id), [folders[1], folders[2], folders[0]])
        try assertPersistedFolders([folders[1], folders[2], folders[0]])
    }

    /// The other drag direction: `move(fromOffsets:toOffset:)` takes pre-removal indices, which
    /// is the half that is easy to get wrong.
    func testMovingAFolderBeforeAnEarlierOne() throws {
        let folders = makeFolders(3)

        store.moveFolder(folders[2], relativeTo: folders[0], position: .before)

        XCTAssertEqual(store.rows.map(\.id), [folders[2], folders[0], folders[1]])
        try assertPersistedFolders([folders[2], folders[0], folders[1]])
    }

    func testMovingAFolderAfterAnEarlierOne() throws {
        let folders = makeFolders(3)

        store.moveFolder(folders[2], relativeTo: folders[0], position: .after)

        XCTAssertEqual(store.rows.map(\.id), [folders[0], folders[2], folders[1]])
        try assertPersistedFolders([folders[0], folders[2], folders[1]])
    }

    /// Both of these land the folder back where it started.
    func testFolderDropsThatChangeNothingAreNoOps() throws {
        let folders = makeFolders(3)

        store.moveFolder(folders[1], relativeTo: folders[1], position: .before)
        store.moveFolder(folders[1], relativeTo: folders[0], position: .after)
        store.moveFolder(folders[1], relativeTo: folders[2], position: .before)

        XCTAssertEqual(store.rows.map(\.id), folders)
        try assertPersistedFolders(folders)
    }

    // MARK: - Snippets in one folder

    func testReorderingSnippetsWithinAFolder() throws {
        let folder = makeFolders(1)[0]
        let snippets = makeSnippets(3, in: folder)

        store.moveSnippet(snippets[0], relativeTo: snippets[2], position: .after)

        XCTAssertEqual(snippetIdentifiers(of: folder), [snippets[1], snippets[2], snippets[0]])
        try assertPersistedSnippets([snippets[1], snippets[2], snippets[0]], in: folder)
    }

    func testMovingASnippetBackwardsWithinAFolder() throws {
        let folder = makeFolders(1)[0]
        let snippets = makeSnippets(3, in: folder)

        store.moveSnippet(snippets[2], relativeTo: snippets[0], position: .before)

        XCTAssertEqual(snippetIdentifiers(of: folder), [snippets[2], snippets[0], snippets[1]])
        try assertPersistedSnippets([snippets[2], snippets[0], snippets[1]], in: folder)
    }

    func testSnippetDropsThatChangeNothingAreNoOps() throws {
        let folder = makeFolders(1)[0]
        let snippets = makeSnippets(3, in: folder)

        store.moveSnippet(snippets[1], relativeTo: snippets[1], position: .after)
        store.moveSnippet(snippets[1], relativeTo: snippets[0], position: .after)
        store.moveSnippet(snippets[1], relativeTo: snippets[2], position: .before)

        XCTAssertEqual(snippetIdentifiers(of: folder), snippets)
        try assertPersistedSnippets(snippets, in: folder)
    }

    // MARK: - Snippets across folders

    func testMovingASnippetIntoAnotherFolderAtAPosition() throws {
        let folders = makeFolders(2)
        let source = makeSnippets(2, in: folders[0])
        let destination = makeSnippets(2, in: folders[1])

        store.moveSnippet(source[0], relativeTo: destination[1], position: .before)

        XCTAssertEqual(snippetIdentifiers(of: folders[0]), [source[1]])
        XCTAssertEqual(snippetIdentifiers(of: folders[1]), [destination[0], source[0], destination[1]])
        try assertPersistedSnippets([source[1]], in: folders[0])
        try assertPersistedSnippets([destination[0], source[0], destination[1]], in: folders[1])
    }

    func testMovingASnippetAfterTheLastSnippetOfAnotherFolder() throws {
        let folders = makeFolders(2)
        let source = makeSnippets(2, in: folders[0])
        let destination = makeSnippets(2, in: folders[1])

        store.moveSnippet(source[1], relativeTo: destination[1], position: .after)

        XCTAssertEqual(snippetIdentifiers(of: folders[1]), destination + [source[1]])
        try assertPersistedSnippets(destination + [source[1]], in: folders[1])
    }

    /// The folder-row drop, and the context menu's "Move to Folder".
    func testMovingASnippetOntoAFolderAppendsIt() throws {
        let folders = makeFolders(2)
        let source = makeSnippets(2, in: folders[0])
        let destination = makeSnippets(1, in: folders[1])

        store.moveSnippet(source[0], toFolder: folders[1])

        XCTAssertEqual(snippetIdentifiers(of: folders[0]), [source[1]])
        XCTAssertEqual(snippetIdentifiers(of: folders[1]), destination + [source[0]])
        try assertPersistedSnippets(destination + [source[0]], in: folders[1])
        XCTAssertTrue(store.expandedFolders.contains(folders[1]))

        // The move itself is synchronous; only the selection is deferred by one run-loop turn,
        // so that it lands after the animated row move rather than inside it.
        waitForRunLoop()
        XCTAssertEqual(store.selection, .snippet(source[0]))
    }

    /// The source folder's `index` column is left with a hole by the move; `appendSnippet` picks
    /// a new snippet's index from the row count, so an un-renumbered source collides on the very
    /// next Add Snippet and two rows come back in an undefined order.
    func testTheSourceFolderIsRenumberedAfterACrossFolderMove() throws {
        let folders = makeFolders(2)
        let source = makeSnippets(2, in: folders[0])

        store.moveSnippet(source[0], toFolder: folders[1])
        store.selection = .folder(folders[0])
        store.addSnippet()

        let added = try XCTUnwrap(snippetIdentifiers(of: folders[0]).last)
        XCTAssertEqual(snippetIdentifiers(of: folders[0]), [source[1], added])
        try assertPersistedSnippets([source[1], added], in: folders[0])
    }

    // MARK: - Refusals

    func testASnippetDroppedOnItsOwnFolderIsANoOp() throws {
        let folder = makeFolders(1)[0]
        let snippets = makeSnippets(2, in: folder)

        store.moveSnippet(snippets[0], toFolder: folder)

        XCTAssertEqual(snippetIdentifiers(of: folder), snippets)
    }

    func testMovingAMissingIdentifierIsANoOp() throws {
        let folders = makeFolders(2)

        store.moveFolder("nope", relativeTo: folders[0], position: .before)
        store.moveSnippet("nope", relativeTo: "also-nope", position: .after)

        XCTAssertEqual(store.rows.map(\.id), folders)
    }
}

// MARK: - Fixtures
private extension SnippetsReorderTests {

    /// `addFolder` appends and publishes synchronously, so the identifiers come straight back
    /// out of `rows` in creation order.
    func makeFolders(_ count: Int) -> [String] {
        (0..<count).forEach { _ in store.addFolder() }
        return store.rows.map(\.id)
    }

    func makeSnippets(_ count: Int, in folderIdentifier: String) -> [String] {
        store.selection = .folder(folderIdentifier)
        (0..<count).forEach { _ in store.addSnippet() }
        return snippetIdentifiers(of: folderIdentifier)
    }

    /// Drains one turn of the main run loop in `.common`, which is where the store schedules
    /// the post-move selection.
    func waitForRunLoop() {
        let settled = expectation(description: "run loop")
        RunLoop.main.perform(inModes: [.common]) { settled.fulfill() }
        wait(for: [settled], timeout: 1)
    }

    func snippetIdentifiers(of folderIdentifier: String) -> [String] {
        store.rows.first { $0.id == folderIdentifier }?.snippets.map(\.id) ?? []
    }

    /// Round-trips through the database. The fetch queues behind the fire-and-forget writes the
    /// store made, on the same serial queue, so it can never observe a half-applied move.
    func assertPersistedFolders(_ expected: [String], file: StaticString = #filePath, line: UInt = #line) throws {
        let fetched = try performSnippet("fetch folders") { try $0.fetchFolders() }
        XCTAssertEqual(fetched.map(\.identifier), expected, file: file, line: line)
    }

    func assertPersistedSnippets(_ expected: [String],
                                 in folderIdentifier: String,
                                 file: StaticString = #filePath,
                                 line: UInt = #line) throws {
        let fetched = try performSnippet("fetch snippets") { try $0.fetchFolders() }
        let folder = fetched.first { $0.identifier == folderIdentifier }
        XCTAssertEqual(folder?.snippets.map(\.identifier), expected, file: file, line: line)
    }
}
