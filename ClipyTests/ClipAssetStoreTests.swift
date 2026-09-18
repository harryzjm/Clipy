//
//  ClipAssetStoreTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
@testable import Clipy

/// The out-of-database half of a clip: the encrypted payload file, the buffer that covers the
/// window before it lands, and the sweep that reclaims it.
final class ClipAssetStoreTests: ClipDBTestCase {

    /// Comfortably over `CPYClip.inlineContentLimit` once JSON-encoded.
    private func largeContents() -> [TypeContent] {
        [.string(String(repeating: "L", count: CPYClip.inlineContentLimit * 2))]
    }

    /// Blocks until everything queued on the asset queue has run.
    private func drainAssetQueue() {
        assetStore.queue.queue.sync {}
    }

    private func rawBytes(of dataPath: String, in store: ClipAssetStore) throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: store.absolutePath(of: dataPath)))
    }

    // MARK: - Encryption

    func testPayloadIsEncryptedOnDisk() throws {
        let payload = Data("a payload worth hiding".utf8)
        let dataPath = ClipAssetStore.makeDataPath()

        try assetStore.writePayload(payload, to: dataPath)

        let stored = try rawBytes(of: dataPath, in: assetStore)
        XCTAssertNotEqual(stored, payload, "the payload must not sit on disk in the clear")
        // AES-GCM `combined`: 12-byte nonce + ciphertext + 16-byte tag.
        XCTAssertEqual(stored.count, payload.count + 28)
        XCTAssertEqual(try assetStore.readPayload(at: dataPath), payload)
    }

    /// The key is `SHA256(databaseKey ‖ dataPath)`, so a file that moves stops opening. That is
    /// the point: the path is part of what is authenticated.
    func testPayloadDoesNotOpenUnderAnotherPath() throws {
        let payload = Data("bound to its path".utf8)
        let original = ClipAssetStore.makeDataPath()
        let moved = ClipAssetStore.makeDataPath()

        try assetStore.writePayload(payload, to: original)
        try FileManager.default.moveItem(atPath: assetStore.absolutePath(of: original),
                                         toPath: assetStore.absolutePath(of: moved))

        XCTAssertThrowsError(try assetStore.readPayload(at: moved))
    }

    /// No keychain means no key, and the databases run in the clear too — `SecretService` trades
    /// confidentiality for availability, and splitting that here would only produce files that
    /// cannot be read back.
    func testPayloadIsPlaintextWithoutAKey() throws {
        let store = ClipAssetStore(secretService: SecretService(secretCode: nil), root: rootPath)
        let payload = Data("nothing to seal it with".utf8)
        let dataPath = ClipAssetStore.makeDataPath()

        try store.writePayload(payload, to: dataPath)

        XCTAssertEqual(try rawBytes(of: dataPath, in: store), payload)
        XCTAssertEqual(try store.readPayload(at: dataPath), payload)
    }

    /// Two payloads sealed under the same database key still get different bytes, because the
    /// per-file key differs. Same plaintext, same size, different ciphertext.
    func testIdenticalPayloadsProduceDifferentCiphertext() throws {
        let payload = Data(repeating: 0xAB, count: 512)
        let first = ClipAssetStore.makeDataPath()
        let second = ClipAssetStore.makeDataPath()

        try assetStore.writePayload(payload, to: first)
        try assetStore.writePayload(payload, to: second)

        XCTAssertNotEqual(try rawBytes(of: first, in: assetStore),
                          try rawBytes(of: second, in: assetStore))
    }

    // MARK: - The window before the write lands

    func testPayloadIsReadableBeforeItReachesTheDisk() throws {
        let contents = largeContents()
        let clip = try XCTUnwrap(CPYClip(contents: contents))

        assetStore.store(clip, contents: contents)

        // Deliberately without draining: this is the state a paste can catch.
        XCTAssertEqual(assetStore.loadPayload(at: clip.dataPath), clip.content)

        drainAssetQueue()
        XCTAssertEqual(assetStore.loadPayload(at: clip.dataPath), clip.content,
                       "and the same bytes must come back off the disk afterwards")
    }

    /// End to end, at both moments: insert, then paste before and after the write settles.
    func testOverflowedClipPastesBeforeAndAfterTheWrite() throws {
        let contents = largeContents()
        let clip = try XCTUnwrap(CPYClip(contents: contents))
        let expected = contents.stringValue

        assetStore.store(clip, contents: contents)
        try perform("insert") { try $0.insertClip(clip) }

        let buffered = try XCTUnwrap(try perform("fetch buffered") { try $0.fetchClip(dataHash: clip.dataHash) })
        XCTAssertNil(buffered.content, "an overflowed clip has no side-table row")
        XCTAssertEqual(buffered.loadContents(assetStore: assetStore)?.stringValue, expected)

        drainAssetQueue()

        let onDisk = try XCTUnwrap(try perform("fetch on disk") { try $0.fetchClip(dataHash: clip.dataHash) })
        XCTAssertEqual(onDisk.loadContents(assetStore: assetStore)?.stringValue, expected)
    }

    /// A write that fails leaves the row alone — losing a clip the user already saw in the menu
    /// is worse than one that refuses to paste, and `loadContents()` says so loudly.
    func testAFailedWriteLeavesNoBufferedPayload() throws {
        let contents = largeContents()
        let clip = try XCTUnwrap(CPYClip(contents: contents))
        // A path whose parent cannot be created, so `writePayload` throws.
        clip.dataPath = "file/nope/deeper"
        let store = ClipAssetStore(secretService: secretService, root: "/dev/null/not-a-directory")

        store.store(clip, contents: contents)
        drainAssetQueue()

        XCTAssertNil(store.loadPayload(at: clip.dataPath))
    }

    // MARK: - Reclaiming

    func testSweepDeletesOnlyUnreferencedFiles() throws {
        let kept = ClipAssetStore.makeDataPath()
        let orphan = ClipAssetStore.makeDataPath()
        try assetStore.writePayload(Data("kept".utf8), to: kept)
        try assetStore.writePayload(Data("orphan".utf8), to: orphan)

        // What `referencedDataFileNames()` hands over: file names, not paths.
        let keptName = try XCTUnwrap(kept.components(separatedBy: "/").last)
        assetStore.sweepFiles(referencing: [keptName])
        drainAssetQueue()

        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: assetStore.absolutePath(of: kept)))
        XCTAssertFalse(fileManager.fileExists(atPath: assetStore.absolutePath(of: orphan)))
    }

    /// The sweep is fed by a live query, so this is the shape it actually runs in.
    func testSweepKeepsWhatTheDatabaseStillReferences() throws {
        let contents = largeContents()
        let clip = try XCTUnwrap(CPYClip(contents: contents))
        assetStore.store(clip, contents: contents)
        try perform("insert") { try $0.insertClip(clip) }
        let orphan = ClipAssetStore.makeDataPath()
        try assetStore.writePayload(Data("nobody points at me".utf8), to: orphan)
        drainAssetQueue()

        let referenced = try perform("referenced") { try $0.referencedDataFileNames() }
        assetStore.sweepFiles(referencing: referenced)
        drainAssetQueue()

        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: assetStore.absolutePath(of: clip.dataPath)))
        XCTAssertFalse(fileManager.fileExists(atPath: assetStore.absolutePath(of: orphan)))
    }
}
