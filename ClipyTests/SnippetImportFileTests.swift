//
//  SnippetImportFileTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
@testable import Clipy

/// Covers the seam the drop destination and the Import button share before anything is written:
/// `isSnippetsFile` decides whether a dragged file is even offered, and `decodeFolders` decides
/// whether the confirmation alert comes up at all. Both are static, so neither needs a database.
///
/// The decoded shape is the documented snippets file format (`script/translate.py`); a test that
/// starts failing here means the format drifted.
final class SnippetImportFileTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SnippetImportFileTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        directory = nil
        try super.tearDownWithError()
    }

    private func write(_ contents: String, as name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - isSnippetsFile

    func testAcceptsJSONAndRejectsOtherFiles() throws {
        XCTAssertTrue(SnippetsEditorStore.isSnippetsFile(try write("[]", as: "snippets.json")))
        XCTAssertTrue(SnippetsEditorStore.isSnippetsFile(try write("[]", as: "SNIPPETS.JSON")))
        XCTAssertFalse(SnippetsEditorStore.isSnippetsFile(try write("[]", as: "snippets.txt")))
        XCTAssertFalse(SnippetsEditorStore.isSnippetsFile(try write("[]", as: "snippets")))
    }

    /// No content type to read for a path that does not exist, so the extension has the last word.
    func testFallsBackToTheExtensionForAMissingFile() {
        let missing = directory.appendingPathComponent("gone.json")
        XCTAssertTrue(SnippetsEditorStore.isSnippetsFile(missing))
        XCTAssertFalse(SnippetsEditorStore.isSnippetsFile(directory.appendingPathComponent("gone.txt")))
    }

    // MARK: - decodeFolders

    func testDecodesFoldersAndSnippets() throws {
        let url = try write("""
        [
          { "index": 0, "enable": true, "title": "Folder", "identifier": "folder-1",
            "snippets": [
              { "index": 0, "enable": true, "title": "T", "content": "C", "identifier": "snippet-1" }
            ]
          }
        ]
        """, as: "snippets.json")

        let folders = try SnippetsEditorStore.decodeFolders(at: url)

        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first?.title, "Folder")
        XCTAssertEqual(folders.first?.identifier, "folder-1")
        XCTAssertEqual(folders.first?.snippets.count, 1)
        XCTAssertEqual(folders.first?.snippets.first?.content, "C")
        // Not in the file: stamped onto each snippet after decoding.
        XCTAssertEqual(folders.first?.snippets.first?.folderIdentifier, "folder-1")
    }

    /// `snippets` is the one optional key; a folder without it decodes to an empty folder.
    func testFolderWithoutSnippetsKeyDecodes() throws {
        let url = try write("""
        [{ "index": 0, "enable": true, "title": "Empty", "identifier": "folder-1" }]
        """, as: "snippets.json")

        XCTAssertEqual(try SnippetsEditorStore.decodeFolders(at: url).first?.snippets.count, 0)
    }

    /// All five snippet keys are required, so one bad snippet fails the whole file rather than
    /// importing a partial tree.
    func testSnippetMissingContentThrows() throws {
        let url = try write("""
        [
          { "index": 0, "enable": true, "title": "Folder", "identifier": "folder-1",
            "snippets": [{ "index": 0, "enable": true, "title": "T", "identifier": "snippet-1" }]
          }
        ]
        """, as: "snippets.json")

        XCTAssertThrowsError(try SnippetsEditorStore.decodeFolders(at: url))
    }

    func testMalformedJSONAndWrongTopLevelShapeThrow() throws {
        XCTAssertThrowsError(try SnippetsEditorStore.decodeFolders(at: try write("not json", as: "a.json")))
        XCTAssertThrowsError(try SnippetsEditorStore.decodeFolders(at: try write("{\"nope\": 1}", as: "b.json")))
    }

    /// A valid but empty file decodes fine; `stageImport` is what refuses it, so that no
    /// confirmation alert offers an import that would do nothing.
    func testEmptyArrayDecodesToNoFolders() throws {
        XCTAssertEqual(try SnippetsEditorStore.decodeFolders(at: try write("[]", as: "snippets.json")).count, 0)
    }
}
