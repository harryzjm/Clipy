//
//  SecretServiceTests.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import XCTest
import CryptoKit
@testable import Clipy

/// Covers the derivation itself, independently of who calls it.
///
/// `ClipAssetStoreTests` only ever asserts that a payload round-trips, which passes under *any*
/// self-consistent derivation — including a changed one. These bytes are a compatibility contract
/// with every payload file already on disk, so they get pinned here against a hash recomputed by
/// hand.
final class SecretServiceTests: XCTestCase {

    private func bytes(of key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }

    func testKeyIsSHA256OfTheSecretThenTheContext() throws {
        let secretCode = ClipDBTestCase.makeSecretCode()
        let context = "file/6F9619FF-8B86-D011-B42D-00CF4FC964FF"

        var hasher = SHA256()
        hasher.update(data: secretCode)
        hasher.update(data: Data(context.utf8))
        let expected = SymmetricKey(data: hasher.finalize())

        let derived = try XCTUnwrap(SecretService(secretCode: secretCode).key(for: context))
        XCTAssertEqual(bytes(of: derived), bytes(of: expected))
    }

    /// Two contexts, one secret, two keys — this is what keeps AES-GCM's nonce-reuse cliff out of
    /// reach without tracking anything.
    func testEachContextGetsItsOwnKey() throws {
        let service = SecretService(secretCode: ClipDBTestCase.makeSecretCode())

        let first = try XCTUnwrap(service.key(for: ClipAssetStore.makeDataPath()))
        let second = try XCTUnwrap(service.key(for: ClipAssetStore.makeDataPath()))

        XCTAssertNotEqual(bytes(of: first), bytes(of: second))
    }

    func testSealedBytesOpenAgainUnderTheSameContext() throws {
        let service = SecretService(secretCode: ClipDBTestCase.makeSecretCode())
        let payload = Data(repeating: 0xAB, count: 512)
        let context = ClipAssetStore.makeDataPath()

        let sealed = try service.seal(payload, context: context)

        XCTAssertNotEqual(sealed, payload)
        XCTAssertEqual(try service.unseal(sealed, context: context), payload)
        XCTAssertThrowsError(try service.unseal(sealed, context: ClipAssetStore.makeDataPath()))
    }

    /// No key is not an error: both directions are the identity function, matching what the
    /// databases do when the keychain is unreachable.
    func testNoKeyMeansPassThroughBothWays() throws {
        let service = SecretService(secretCode: nil)
        let payload = Data("nothing to seal it with".utf8)

        XCTAssertNil(service.key(for: "file/x"))
        XCTAssertEqual(try service.seal(payload, context: "file/x"), payload)
        XCTAssertEqual(try service.unseal(payload, context: "file/x"), payload)
    }
}
