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
/// Each test gets its own `ClipyBox` rooted in a fresh scratch directory — never
/// `ClipyBox.shared` — so nothing here can reach the developer's real clipboard history, and
/// every test starts from an empty database with migrations freshly applied.
class ClipDBTestCase: XCTestCase {

    private(set) var box: ClipyBox!
    private var rootPath: String!
    private let disposeBag = DisposeBag()

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("ClipyTests-\(UUID().uuidString)")
        box = ClipyBox(path: rootPath)
    }

    override func tearDownWithError() throws {
        box = nil
        if let rootPath {
            try? FileManager.default.removeItem(atPath: rootPath)
        }
        try super.tearDownWithError()
    }

    /// Runs one transaction and blocks until it completes, returning its value and rethrowing
    /// whatever it threw.
    ///
    /// `ClipyBox` transactions run on their own serial queue and deliver on another, so waiting
    /// on the main thread here never deadlocks. Pass `ignoreTransaction` for statements SQLite
    /// refuses to run inside a transaction — `VACUUM` is the one that matters.
    @discardableResult
    func perform<T>(_ name: String,
                    ignoreTransaction: Bool = false,
                    timeout: TimeInterval = 30,
                    _ body: @escaping (ClipServiceTransaction) throws -> T) throws -> T {
        let expectation = expectation(description: name)
        var value: T?
        var caughtError: Error?

        box.clipTransaction(ignoreTransaction: ignoreTransaction, body)
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
