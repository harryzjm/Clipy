//
//  SnippetLanguageMigrationTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
import RxSwift
import WCDBSwift
@testable import Clipy

/// `snippet.language` arrived as migration 2, and that migration is nothing but migration 1's
/// `create(table:of:)` run again — it relies on WCDB reconciling an existing table against the
/// model and emitting `ALTER TABLE snippet ADD COLUMN` for what is missing.
///
/// That is a load-bearing assumption about a dependency, and getting it wrong is silent: every
/// upgrading user's snippets would fail to write, or read back without a language. So the test
/// builds the pre-migration shape for real — drop the table, recreate it from a v1 copy of the
/// model, rewind the version MMKV records — and reopens the box.
final class SnippetLanguageMigrationTests: XCTestCase {

    /// `CPYSnippetTable` as it was before `language`. Same table name on purpose.
    private struct LegacySnippetTable: TableCodable {

        var identifier: String = ""
        var folderIdentifier: String = ""
        var index: Int = 0
        var enable: Bool = true
        var title: String = ""
        var content: String = ""

        enum CodingKeys: String, CodingTableKey {
            typealias Root = LegacySnippetTable

            case identifier
            case folderIdentifier = "folder_identifier"
            case index = "snippet_index"
            case enable
            case title
            case content

            static let objectRelationalMapping = TableBinding(CodingKeys.self) {
                BindColumnConstraint(.identifier, isPrimary: true, isNotNull: true)
                BindIndex(folderIdentifier, namedWith: "_folderIdentifierIndex")
            }
        }
    }

    private var rootPath: String!
    private var secretCode: Data!
    private let disposeBag = DisposeBag()

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("SnippetLanguageMigrationTests-\(UUID().uuidString)")
        secretCode = ClipDBTestCase.makeSecretCode()
    }

    override func tearDownWithError() throws {
        if let rootPath {
            try? FileManager.default.removeItem(atPath: rootPath)
        }
        rootPath = nil
        secretCode = nil
        try super.tearDownWithError()
    }

    func testMigrationAddsTheLanguageColumnToAnExistingTable() throws {
        let identifier = UUID().uuidString

        // A database as it stood before `language` existed, holding one snippet.
        try withBox { box in
            try perform(on: box, "downgrade") { transaction in
                let db = transaction.snippetDb.db
                try db.drop(table: CPYSnippetTable.tableName)
                try db.create(table: CPYSnippetTable.tableName, of: LegacySnippetTable.self)

                var legacy = LegacySnippetTable()
                legacy.identifier = identifier
                legacy.title = "Old snippet"
                legacy.content = "print(\"hi\")"
                try db.insertOrReplace(legacy, intoTable: CPYSnippetTable.tableName)

                // What the migrator reads to decide which steps still have to run.
                transaction.snippetDb.store.set(Int32(1), forKey: "com.clipy.database.snippet.db.version")
            }
        }

        // Reopening runs migration 2 against that file.
        try withBox { box in
            let migrated = try perform(on: box, "fetch") { transaction in
                try transaction.snippetDb.fetchSnippetTable(identifier: identifier)
            }
            let snippet = try XCTUnwrap(migrated, "the pre-migration row survived the upgrade")
            XCTAssertEqual(snippet.title, "Old snippet")
            XCTAssertEqual(snippet.language, CPYSnippet.plainTextLanguage,
                           "the column's SQL default is what an upgraded row reads back as")

            // And the column is writable, which is what actually breaks if the ALTER never ran.
            var updated = snippet
            updated.language = "swift"
            try perform(on: box, "update") { try $0.snippetDb.upsertSnippet(updated) }

            let reread = try perform(on: box, "re-fetch") {
                try $0.snippetDb.fetchSnippetTable(identifier: identifier)
            }
            XCTAssertEqual(reread?.language, "swift")
        }
    }

    /// A box built fresh — migrations 1 and 2 both applied to an empty file — round-trips the
    /// column too. The pair is the point: neither path may be the only one that works.
    func testAFreshDatabaseStoresTheLanguage() throws {
        try withBox { box in
            var snippet = CPYSnippetTable()
            snippet.identifier = UUID().uuidString
            snippet.language = "json"
            try perform(on: box, "insert") { try $0.snippetDb.upsertSnippet(snippet) }

            let stored = try perform(on: box, "fetch") {
                try $0.snippetDb.fetchSnippetTable(identifier: snippet.identifier)
            }
            XCTAssertEqual(stored?.language, "json")
        }
    }

    // MARK: - Helpers

    /// Scopes a box so its database handles are closed before the next one opens the same file.
    private func withBox(_ body: (ClipyBox) throws -> Void) throws {
        let box = ClipyBox(path: rootPath, secretCode: secretCode)
        defer { box.setCanBeginTransactions(false) }
        try body(box)
    }

    /// Snippet-side twin of `ClipDBTestCase.perform`.
    @discardableResult
    private func perform<T>(on box: ClipyBox,
                            _ name: String,
                            _ body: @escaping (SnippetServiceTransaction) throws -> T) throws -> T {
        let expectation = expectation(description: name)
        var value: T?
        var caughtError: Error?

        box.snippetTransaction(body)
            .subscribe(onNext: {
                value = $0
                expectation.fulfill()
            }, onError: { error in
                caughtError = error
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 30)
        if let caughtError {
            throw caughtError
        }
        return try XCTUnwrap(value, "\(name) completed without producing a value")
    }
}
