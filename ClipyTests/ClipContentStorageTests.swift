//
//  ClipContentStorageTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
@testable import Clipy

/// Where a clip's payload lives, and that it leaves with the clip.
///
/// A payload is inline in `clip_content` when it is small and in a `file/<uuid>` file when it is
/// not. The two are exclusive *in the database*; a freshly captured clip holds both, because the
/// file write is asynchronous and `content` is what gets written. Both halves have to survive a
/// round trip, and every delete path has to take the payload with it — the expiry sweep deletes
/// by predicate, so nothing in Swift ever sees which hashes went.
final class ClipContentStorageTests: ClipDBTestCase {

    // MARK: - Fixtures

    /// Comfortably under `CPYClip.inlineContentLimit` once JSON-encoded.
    private func smallContents(_ text: String = "a short clipping") -> [TypeContent] {
        [.string(text)]
    }

    /// Comfortably over it.
    private func largeContents() -> [TypeContent] {
        [.string(String(repeating: "L", count: CPYClip.inlineContentLimit * 2))]
    }

    private func makeClip(_ contents: [TypeContent], file: StaticString = #filePath, line: UInt = #line) throws -> CPYClip {
        try XCTUnwrap(CPYClip(contents: contents), "CPYClip(contents:) returned nil", file: file, line: line)
    }

    /// Writes an overflowed clip's payload out now, instead of waiting on the asset queue.
    private func flushPayload(of clip: CPYClip, file: StaticString = #filePath, line: UInt = #line) throws {
        let payload = try XCTUnwrap(clip.content, "an overflowed clip still carries its payload", file: file, line: line)
        try assetStore.writePayload(payload, to: clip.dataPath)
    }

    // MARK: - Where the payload goes

    func testSmallPayloadIsStoredInline() throws {
        let clip = try makeClip(smallContents())

        XCTAssertNotNil(clip.content, "a small payload belongs in the database")
        XCTAssertTrue(clip.dataPath.isEmpty, "an inline payload must not also claim a file")
    }

    /// The initializer only *names* the file. Writing it is the asset queue's job, so nothing is
    /// on disk yet at this point — that is the whole change.
    func testLargePayloadIsNamedButNotYetWritten() throws {
        let clip = try makeClip(largeContents())

        XCTAssertNotNil(clip.content, "the payload has to survive until it reaches the disk")
        XCTAssertTrue(clip.dataPath.hasPrefix("file/"), "got \(clip.dataPath)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: assetStore.absolutePath(of: clip.dataPath)),
                       "CPYClip(contents:) must not touch the filesystem")
    }

    func testEmptyContentsProduceNoClip() {
        XCTAssertNil(CPYClip(contents: []))
    }

    // MARK: - Round trip

    func testInlinePayloadSurvivesTheRoundTrip() throws {
        let text = "round trip me"
        let clip = try makeClip(smallContents(text))
        try perform("insert") { try $0.insertClip(clip) }

        let fetched = try XCTUnwrap(try perform("fetch") { try $0.fetchClip(dataHash: clip.dataHash) })
        XCTAssertNotNil(fetched.content, "fetchClip(dataHash:) must carry the inline payload")
        XCTAssertEqual(fetched.loadContents(assetStore: assetStore)?.stringValue, text)
    }

    func testOverflowedPayloadSurvivesTheRoundTrip() throws {
        let clip = try makeClip(largeContents())
        try perform("insert") { try $0.insertClip(clip) }
        try flushPayload(of: clip)

        let fetched = try XCTUnwrap(try perform("fetch") { try $0.fetchClip(dataHash: clip.dataHash) })
        XCTAssertNil(fetched.content, "an overflowed clip has no side-table row")
        XCTAssertEqual(fetched.loadContents(assetStore: assetStore)?.stringValue,
                       clip.loadContents(assetStore: assetStore)?.stringValue)
    }

    /// The whole reason the payload is a side table: list reads must not drag it along.
    func testListReadsDoNotLoadThePayload() throws {
        let clip = try makeClip(smallContents())
        try perform("insert") { try $0.insertClip(clip) }

        let listed = try perform("list") { try $0.fetchClips(ascending: false, limit: 10) }
        XCTAssertEqual(listed.count, 1)
        XCTAssertNil(listed.first?.content, "list queries must leave `content` nil")
        XCTAssertNil(listed.first?.loadContents(assetStore: assetStore),
                     "and a clip from a list read cannot be pasted")
    }

    func testRepeatedInsertKeepsOneSideTableRow() throws {
        let clip = try makeClip(smallContents("copied twice"))
        try perform("insert") { try $0.insertClip(clip) }
        try perform("insert again") { try $0.insertClip(clip) }

        XCTAssertEqual(try perform("count clips") { try $0.clipCount() }, 1)
        XCTAssertEqual(try perform("count contents") { try $0.clipDb.contentCount() }, 1)

        let fetched = try XCTUnwrap(try perform("fetch") { try $0.fetchClip(dataHash: clip.dataHash) })
        XCTAssertEqual(fetched.loadContents(assetStore: assetStore)?.stringValue, "copied twice")
    }

    /// An inline row for the same hash must not outlive a switch to file storage — otherwise it
    /// would be preferred over the file on read.
    func testOverflowedInsertClearsAStaleInlineRow() throws {
        let clip = try makeClip(smallContents())
        try perform("insert inline") { try $0.insertClip(clip) }
        XCTAssertEqual(try perform("count contents") { try $0.clipDb.contentCount() }, 1)

        // Same hash, payload now claimed to live in a file.
        clip.dataPath = "file/not-really-there"
        try perform("insert overflowed") { try $0.insertClip(clip) }

        XCTAssertEqual(try perform("count contents") { try $0.clipDb.contentCount() }, 0)
    }

    // MARK: - Every delete path takes the payload with it

    func testDeletingOneClipDropsItsPayload() throws {
        let kept = try makeClip(smallContents("kept"))
        let dropped = try makeClip(smallContents("dropped"))
        try perform("insert kept") { try $0.insertClip(kept) }
        try perform("insert dropped") { try $0.insertClip(dropped) }

        try perform("delete") { try $0.deleteClip(dataHash: dropped.dataHash) }

        XCTAssertEqual(try perform("count contents") { try $0.clipDb.contentCount() }, 1)
        XCTAssertEqual(try perform("orphans") { try $0.clipDb.orphanedContentCount() }, 0)
        XCTAssertNil(try perform("fetch dropped") { try $0.clipDb.fetchContent(dataHash: dropped.dataHash) })
        XCTAssertNotNil(try perform("fetch kept") { try $0.clipDb.fetchContent(dataHash: kept.dataHash) })
    }

    /// Expiry deletes by predicate, so `clip_content_ad` is the only thing keeping the side table
    /// in step here.
    func testExpirySweepDropsPayloads() throws {
        let old = try makeClip(smallContents("old"))
        old.updateTime = 1_000
        let recent = try makeClip(smallContents("recent"))
        recent.updateTime = 9_000
        try perform("insert old") { try $0.insertClip(old) }
        try perform("insert recent") { try $0.insertClip(recent) }

        try perform("expire") { try $0.deleteExpiredClips(olderThan: 5_000) }

        XCTAssertEqual(try perform("count clips") { try $0.clipCount() }, 1)
        XCTAssertEqual(try perform("count contents") { try $0.clipDb.contentCount() }, 1)
        XCTAssertEqual(try perform("orphans") { try $0.clipDb.orphanedContentCount() }, 0)
        XCTAssertNil(try perform("fetch old") { try $0.clipDb.fetchContent(dataHash: old.dataHash) })
    }

    /// `DELETE FROM clip` with no `WHERE` is the shape SQLite's truncate optimization targets,
    /// and that path skips per-row triggers. `deleteAllClips()` clears the side table itself, so
    /// the payload half is unconditional; the FTS assertion checks whether the existing mirror —
    /// which has only ever relied on its trigger here — actually survives this path.
    func testClearingHistoryDropsEveryPayload() throws {
        let inline = try makeClip(smallContents("inline"))
        let overflowed = try makeClip(largeContents())
        try perform("insert inline") { try $0.insertClip(inline) }
        try perform("insert overflowed") { try $0.insertClip(overflowed) }
        XCTAssertEqual(try perform("count contents") { try $0.clipDb.contentCount() }, 1)

        try perform("clear") { try $0.clearAllClips() }

        XCTAssertEqual(try perform("count clips") { try $0.clipCount() }, 0)
        XCTAssertEqual(try perform("count contents") { try $0.clipDb.contentCount() }, 0)
        XCTAssertEqual(try perform("count fts") { try $0.clipDb.ftsCount() }, 0,
                       "clip_fts is left behind when history is cleared — pre-existing, track separately")
    }
}
