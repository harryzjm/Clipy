//
//  ClipDBTestCase.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
import RxSwift
@testable import Clipy

/// Base for tests that need a real `clip.db`.
///
/// Each test gets its own `ClipyBox` rooted in a fresh scratch directory, so nothing here can
/// reach the developer's real clipboard history and every test starts from an empty database
/// with migrations freshly applied. It gets a matching `ClipAssetStore` over that same
/// directory — the two are separate objects, held side by side here exactly as `Environment`
/// holds them — so `tearDown` takes the payload files with it.
///
/// The key is generated here rather than left to `SecretService()`: tests must not touch the
/// login keychain, and passing one means every suite below runs against an encrypted database,
/// which is how the app ships.
class ClipDBTestCase: XCTestCase {

    /// The installation secret the box and the asset store below are both built from, exactly as
    /// `Environment` builds them.
    private(set) var secretService: SecretService!
    private(set) var box: ClipyBox!
    /// The clip state that lives outside the databases, under the same `secretService`.
    private(set) var assetStore: ClipAssetStore!
    private(set) var rootPath: String!
    private let disposeBag = DisposeBag()

    /// The raw key `setUp` built this test's box with, so a test can reopen the same file.
    /// Flat-mapped rather than force-unwrapped because `tearDown` nils the service out from under it.
    var secretCode: Data? { secretService.flatMap { $0.secretCode } }

    /// Override to run a suite against a plaintext database.
    var usesEncryptedDatabase: Bool { true }

    static func makeSecretCode() -> Data {
        Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("ClipyTests-\(UUID().uuidString)")
        secretService = SecretService(secretCode: usesEncryptedDatabase ? Self.makeSecretCode() : nil)
        box = ClipyBox(path: rootPath, secretCode: secretService.secretCode)
        assetStore = ClipAssetStore(secretService: secretService, root: rootPath)
    }

    override func tearDownWithError() throws {
        box = nil
        assetStore = nil
        secretService = nil
        if let rootPath {
            try? FileManager.default.removeItem(atPath: rootPath)
        }
        try super.tearDownWithError()
    }

    /// Runs one transaction and blocks until it completes, returning its value and rethrowing
    /// whatever it threw.
    ///
    /// `ClipyBox` transactions run on their own serial queue and deliver on another, so waiting
    /// on the main thread here never deadlocks. Pass `on:` to run against a box other than the
    /// one `setUp` built. Pass `ignoreTransaction` for statements SQLite refuses to run inside
    /// a transaction — `VACUUM` is the one that matters.
    @discardableResult
    func perform<T>(_ name: String,
                    on box: ClipyBox? = nil,
                    ignoreTransaction: Bool = false,
                    timeout: TimeInterval = 30,
                    _ body: @escaping (ClipServiceTransaction) throws -> T) throws -> T {
        let expectation = expectation(description: name)
        var value: T?
        var caughtError: Error?

        (box ?? self.box).clipTransaction(ignoreTransaction: ignoreTransaction, body)
            .subscribe(onNext: {
                value = $0
                expectation.fulfill()
            }, onError: { error in
                caughtError = error
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: timeout)
        if let caughtError {
            throw caughtError
        }
        return try XCTUnwrap(value, "\(name) completed without producing a value")
    }
}
