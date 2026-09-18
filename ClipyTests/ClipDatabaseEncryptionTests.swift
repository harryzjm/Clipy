//
//  ClipDatabaseEncryptionTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
@testable import Clipy

/// Covers the SQLCipher key `ClipyBox` hands down to every `DataStore`.
///
/// The assertions are deliberately made against the bytes on disk rather than against the API:
/// `setCipher(key: nil)` means *no* encryption, so a key that gets lost on the way down produces
/// a database that reads and writes perfectly while storing everything in the clear. Only the
/// file can tell the two apart.
final class ClipDatabaseEncryptionTests: ClipDBTestCase {

    /// The plaintext SQLite header. SQLCipher encrypts page 1 header included, so an encrypted
    /// file cannot begin with it.
    private static let sqliteMagic = Data("SQLite format 3\0".utf8)

    func testDatabaseFileIsEncryptedOnDisk() throws {
        try insertClip(hash: "a", title: "unmistakable needle")

        let bytes = try databaseBytes(in: rootPath)
        XCTAssertFalse(bytes.starts(with: Self.sqliteMagic), "clip.db still begins with the SQLite header")
        XCTAssertNil(bytes.range(of: Data("unmistakable needle".utf8)), "clip title is readable on disk")
    }

    /// The control. Without it the test above would also pass on a file that was empty, missing,
    /// or written in some other format — and there would be nothing pinning the magic constant.
    func testPlaintextDatabaseIsReadableOnDisk() throws {
        let plainPath = (rootPath as NSString).appendingPathComponent("plaintext")
        let plainBox = ClipyBox(path: plainPath, secretCode: nil)

        try insertClip(hash: "a", title: "unmistakable needle", on: plainBox)

        let bytes = try databaseBytes(in: plainPath)
        XCTAssertTrue(bytes.starts(with: Self.sqliteMagic))
        XCTAssertNotNil(bytes.range(of: Data("unmistakable needle".utf8)))
    }

    /// The key alone, with no help from an already-open handle, decrypts the file.
    func testSameKeyReadsExistingRows() throws {
        try insertClip(hash: "a", title: "alpha")

        let reopened = ClipDB(rootPath: try copyOfDatabase(), name: "clip.db", secretCode: secretCode, store: box.store)
        XCTAssertEqual(try reopened.clipCount(), 1)
    }

    /// A wrong key is indistinguishable from a lost one: the file will not open at all.
    func testWrongKeyCannotRead() throws {
        try insertClip(hash: "a", title: "alpha")

        let reopened = ClipDB(rootPath: try copyOfDatabase(), name: "clip.db", secretCode: Self.makeSecretCode(), store: box.store)
        XCTAssertThrowsError(try reopened.clipCount())
    }

    /// The wrong key is reported as one, rather than as corruption or as nothing at all — the
    /// alert `DatabaseResetPrompt` puts on screen says which of the two happened.
    func testWrongKeyIsOfferedForReset() throws {
        try insertClip(hash: "a", title: "alpha")
        let recovery = StubRecovery(answer: false)

        _ = ClipDB(rootPath: try copyOfDatabase(), name: "clip.db", secretCode: Self.makeSecretCode(),
                   store: box.store, recovery: recovery)

        XCTAssertEqual(recovery.asked, [.keyMismatch])
    }

    /// Accepting the reset leaves a working, empty database behind.
    ///
    /// Also pins the MMKV half of it: this shares `box.store`, where `clip.db` is already
    /// recorded at its current schema version. A reset that deleted the file without clearing
    /// that version would skip every migration, and `clipCount()` would throw on a database with
    /// no `clip` table in it.
    func testAcceptedResetRebuildsAnEmptyDatabase() throws {
        try insertClip(hash: "a", title: "alpha")
        let path = try copyOfDatabase()

        let reopened = ClipDB(rootPath: path, name: "clip.db", secretCode: Self.makeSecretCode(),
                              store: box.store, recovery: StubRecovery(answer: true))

        XCTAssertEqual(try reopened.clipCount(), 0)
        XCTAssertEqual(try reopened.ftsCount(), 0, "the FTS mirror was not rebuilt with the table")
    }

    /// Declining keeps the file exactly as it was — the point of asking at all.
    func testDeclinedResetLeavesTheFileAlone() throws {
        try insertClip(hash: "a", title: "alpha")
        let path = try copyOfDatabase()
        // `clip.db` itself, not `databaseBytes`: a failed open still rewrites the `-shm` scratch
        // file, and that is not what "left alone" is about.
        let file = URL(fileURLWithPath: (path as NSString).appendingPathComponent("clip.db"))
        let before = try Data(contentsOf: file)

        let reopened = ClipDB(rootPath: path, name: "clip.db", secretCode: Self.makeSecretCode(),
                              store: box.store, recovery: StubRecovery(answer: false))

        XCTAssertThrowsError(try reopened.clipCount())
        XCTAssertEqual(try Data(contentsOf: file), before)
    }
}

/// Answers without a window, so the suite never blocks on an alert.
private final class StubRecovery: DatabaseRecovery {

    private(set) var asked: [DatabaseOpenFailure] = []
    private let answer: Bool

    init(answer: Bool) {
        self.answer = answer
    }

    func shouldReset(databaseNamed name: String, failure: DatabaseOpenFailure) -> Bool {
        asked.append(failure)
        return answer
    }
}

// MARK: - Helpers
private extension ClipDatabaseEncryptionTests {

    func insertClip(hash: String, title: String, on box: ClipyBox? = nil) throws {
        let clip = CPYClip()
        clip.dataHash = hash
        clip.dataPath = "\(hash).data"
        clip.title = title
        clip.primaryType = "public.utf8-plain-text"
        clip.updateTime = 1
        clip.clipType = .text

        try perform("insert \(hash)", on: box) { try $0.insertClip(clip) }
    }

    /// A copy of `clip.db` and its sidecars in a fresh directory.
    ///
    /// The copy is the point: WCDB keys its databases by path, so a second `ClipDB` over the
    /// *same* path reuses the handle the box already has open — it would read rows happily under
    /// any key at all, and prove nothing about the encryption.
    func copyOfDatabase() throws -> String {
        let manager = FileManager.default
        let destination = (rootPath as NSString).appendingPathComponent("copy-\(UUID().uuidString)")
        try manager.createDirectory(atPath: destination, withIntermediateDirectories: true)

        // `-wal` included: a row written moments ago may not have been checkpointed yet.
        for name in try manager.contentsOfDirectory(atPath: rootPath).filter({ $0.hasPrefix("clip.db") }) {
            try manager.copyItem(atPath: (rootPath as NSString).appendingPathComponent(name),
                                 toPath: (destination as NSString).appendingPathComponent(name))
        }
        return destination
    }

    /// Every byte WCDB owns for `clip.db` — the database itself plus whatever `-wal` / `-shm`
    /// sidecars exist, since a row written moments ago may still live only in the WAL.
    func databaseBytes(in directory: String) throws -> Data {
        let names = try FileManager.default.contentsOfDirectory(atPath: directory)
            .filter { $0.hasPrefix("clip.db") }
            .sorted()
        XCTAssertTrue(names.contains("clip.db"), "clip.db was never created in \(directory)")

        return try names.reduce(into: Data()) { bytes, name in
            bytes += try Data(contentsOf: URL(fileURLWithPath: (directory as NSString).appendingPathComponent(name)))
        }
    }
}
