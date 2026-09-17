//
//  ClipFtsIndexTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
@testable import Clipy

/// Covers the `clip_fts` mirror the SQL triggers maintain.
///
/// The mirror is keyed by rowid (`clip_fts.rowid == clip.rowid`), which is what lets fts5 seek
/// instead of scan. Nothing in Swift enforces that correspondence, so every write path is
/// checked two ways: the row counts agree, and a search actually finds — or stops finding — the
/// content it should. A count on its own would pass even if the rowids had drifted apart.
final class ClipFtsIndexTests: ClipDBTestCase {

    /// A genuinely new clip lands in both tables and is searchable.
    func testInsertIndexesClip() throws {
        try insertClip(hash: "a", title: "alpha beta", updateTime: 1)

        try assertCountsAgree(expecting: 1)
        XCTAssertEqual(try searchHashes("alpha"), ["a"])
    }

    /// Re-copying the same content replaces the index entry rather than adding a second one.
    ///
    /// This is the case the BEFORE INSERT trigger exists for. `insertClip` uses
    /// `INSERT OR REPLACE`, and SQLite does not fire AFTER DELETE for the row a replace drops
    /// unless `recursive_triggers` is on — which it is not. Without that trigger the old FTS row
    /// survives, so the stale title stays searchable and the index grows without bound.
    func testRepeatedInsertReplacesIndexEntry() throws {
        try insertClip(hash: "a", title: "original content", updateTime: 1)
        try insertClip(hash: "a", title: "revised content", updateTime: 2)

        try assertCountsAgree(expecting: 1)
        XCTAssertEqual(try searchHashes("revised"), ["a"])
        XCTAssertEqual(try searchHashes("original"), [], "stale FTS row survived the replace")
    }

    /// Deleting one clip takes its index entry with it and leaves the others alone.
    func testDeleteRemovesIndexEntry() throws {
        try insertClip(hash: "a", title: "keep this", updateTime: 1)
        try insertClip(hash: "b", title: "drop this", updateTime: 2)

        try perform("delete") { try $0.deleteClip(dataHash: "b") }

        try assertCountsAgree(expecting: 1)
        XCTAssertEqual(try searchHashes("keep"), ["a"])
        XCTAssertEqual(try searchHashes("drop"), [])
    }

    /// The expiry sweep deletes by predicate, so Swift never learns which rows died — the
    /// trigger is the only thing keeping the index in step.
    func testExpiryRemovesIndexEntries() throws {
        try insertClip(hash: "old", title: "stale entry", updateTime: 10)
        try insertClip(hash: "new", title: "fresh entry", updateTime: 20)

        try perform("expire") { try $0.deleteExpiredClips(olderThan: 15) }

        try assertCountsAgree(expecting: 1)
        XCTAssertEqual(try searchHashes("fresh"), ["new"])
        XCTAssertEqual(try searchHashes("stale"), [])
    }

    /// Clearing the history empties the index too.
    func testClearAllEmptiesIndex() throws {
        try insertClip(hash: "a", title: "first entry", updateTime: 1)
        try insertClip(hash: "b", title: "second entry", updateTime: 2)

        try perform("clear") { try $0.clearAllClips() }

        try assertCountsAgree(expecting: 0)
        XCTAssertEqual(try searchHashes("entry"), [])
    }

    /// `VACUUM` renumbers `clip`'s rowids, so `ClipServiceTransaction.vacuum()` rebuilds the
    /// mirror afterwards.
    ///
    /// The delete at the end is the part that matters. Counts and searches would both still pass
    /// on a mirror whose rowids had drifted — the rows are all there, just mislabelled. Only a
    /// rowid-keyed delete exposes it: with the correspondence broken, the AFTER DELETE trigger
    /// removes some other clip's index entry and the one actually deleted stays searchable.
    func testVacuumRealignsIndex() throws {
        for (index, word) in ["alpha", "bravo", "charlie", "delta"].enumerated() {
            try insertClip(hash: word, title: "\(word) entry", updateTime: index)
        }

        try perform("vacuum", ignoreTransaction: true) { try $0.vacuum() }

        try assertCountsAgree(expecting: 4)
        XCTAssertEqual(try searchHashes("bravo"), ["bravo"], "index lost a row across VACUUM")

        try perform("delete after vacuum") { try $0.deleteClip(dataHash: "bravo") }

        try assertCountsAgree(expecting: 3)
        XCTAssertEqual(try searchHashes("bravo"), [], "rowids drifted: the delete hit another row")
        XCTAssertEqual(try searchHashes("charlie"), ["charlie"], "the delete took an innocent row")
    }

    /// FTS results come back newest first, which is what the history menu shows and what the
    /// `LIMIT` selects on. The query orders by rowid, so this also pins the assumption that
    /// rowid tracks recency — including for a re-copied clip, which `INSERT OR REPLACE` moves to
    /// a fresh `max(rowid) + 1`.
    func testFtsResultsAreNewestFirst() throws {
        try insertClip(hash: "a", title: "shared word alpha", updateTime: 1)
        try insertClip(hash: "b", title: "shared word bravo", updateTime: 2)
        try insertClip(hash: "c", title: "shared word charlie", updateTime: 3)

        XCTAssertEqual(try searchHashes("shared"), ["c", "b", "a"])

        try insertClip(hash: "a", title: "shared word alpha", updateTime: 4)

        XCTAssertEqual(try searchHashes("shared"), ["a", "c", "b"])
    }
}

// MARK: - Helpers
private extension ClipFtsIndexTests {

    func insertClip(hash: String, title: String, updateTime: Int) throws {
        let clip = CPYClip()
        clip.dataHash = hash
        clip.dataPath = "\(hash).data"
        clip.title = title
        clip.primaryType = "public.utf8-plain-text"
        clip.updateTime = updateTime
        clip.clipType = .text

        try perform("insert \(hash)") { try $0.insertClip(clip) }
    }

    /// `data_hash` of every FTS hit, in the order the query returned them.
    func searchHashes(_ query: String) throws -> [String] {
        let filter = ClipFilter(query: query, mode: .fts)
        let result = try perform("search \(query)") {
            try $0.fetchClips(filter: filter, limit: 200)
        }
        return result.clips.map { $0.dataHash }
    }

    /// Both tables hold `expected` rows. `ftsCount()` is DEBUG-only, which is where tests run.
    func assertCountsAgree(expecting expected: Int,
                           file: StaticString = #filePath,
                           line: UInt = #line) throws {
        let counts = try perform("counts") {
            (clip: try $0.clipCount(), fts: try $0.clipDb.ftsCount())
        }
        XCTAssertEqual(counts.clip, expected, "clip row count", file: file, line: line)
        XCTAssertEqual(counts.fts, expected, "clip_fts row count", file: file, line: line)
    }
}
