//
//  SecretService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation
import CryptoKit
import Security

final class SecretService {
    let secretCode: Data?

    init(secretCode: Data?) {
        self.secretCode = secretCode
    }

    convenience init() {
        self.init(secretCode: Keychain.resolve())
    }
}

// MARK: - Sealing
extension SecretService {

    /// A key of this payload's own, `SHA256(secretCode ‖ context)`.
    ///
    /// Per-context rather than one key for everything: callers pass something carrying a fresh
    /// UUID (`ClipAssetStore` passes the relative `dataPath`), so no two payloads are ever sealed
    /// under the same key and AES-GCM's nonce-reuse cliff is out of reach without tracking
    /// anything. The flip side is deliberate — a file renamed or moved no longer opens, because
    /// its path is what keys it.
    ///
    /// Internal rather than private so `SecretServiceTests` can pin these exact bytes: the
    /// derivation is a compatibility contract with every payload file already on disk.
    func key(for context: String) -> SymmetricKey? {
        guard let secretCode else { return nil }
        var hasher = SHA256()
        hasher.update(data: secretCode)
        hasher.update(data: Data(context.utf8))
        return SymmetricKey(data: hasher.finalize())
    }

    /// AES-GCM `combined`: 12B nonce + ciphertext + 16B tag.
    ///
    /// Without a key this is the identity function, not an error — matching what the databases do
    /// in the same situation.
    func seal(_ payload: Data, context: String) throws -> Data {
        guard let key = key(for: context) else { return payload }
        guard let combined = try AES.GCM.seal(payload, using: key).combined else {
            // Only nil for a non-default nonce size, which this never asks for.
            throw CryptoKitError.incorrectParameterSize
        }
        return combined
    }

    /// Throws when the bytes are truncated, or were sealed under a different key or context.
    func unseal(_ stored: Data, context: String) throws -> Data {
        guard let key = key(for: context) else { return stored }
        return try AES.GCM.open(AES.GCM.SealedBox(combined: stored), using: key)
    }
}

// MARK: - Keychain
private extension SecretService {

    /// Where the installation key lives.
    ///
    /// This deliberately uses the *legacy file keychain* — `kSecUseDataProtectionKeychain` is left
    /// unset, which on macOS means false. The data protection keychain would require a
    /// `keychain-access-groups` entitlement, and Clipy ships unsandboxed and, in Release, ad-hoc
    /// signed, so it has none.
    enum Keychain {

        // `service` and `account` address an item already in users' keychains. They are persisted
        // identifiers, not a description of this Swift type: changing either mints a fresh key and
        // orphans every database and payload file the old one encrypted.
        //
        // Debug and Release already keep separate Application Support directories
        // (`Constants.Application.name`), so they must keep separate keys too — otherwise one
        // build's key would be handed to the other build's database.
        static let service = "com.clipy-app.\(Constants.Application.name).database"
        static let account = "database-key"
        static let label = "Clipy Database Key"
        static let byteCount = 32

        /// What the keychain had to say. The difference between `missing` and `failed` is the
        /// whole safety story: minting a replacement for a key that is merely *unreadable* would
        /// hand the databases a wrong key, and a wrong key is indistinguishable from a lost one.
        enum Lookup {
            case found(Data)
            case missing
            case failed
        }

        static func resolve() -> Data? {
            switch load() {
            case .found(let key):
                return key
            case .failed:
                return nil
            case .missing:
                return create()
            }
        }

        static func load() -> Lookup {
            var query = baseQuery
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            switch status {
            case errSecSuccess:
                guard let key = item as? Data, key.count == byteCount else {
                    lError("Stored database key is malformed; refusing to replace it")
                    return .failed
                }
                return .found(key)
            case errSecItemNotFound:
                return .missing
            default:
                lError("Failed to read the database key from the keychain, status:", status)
                return .failed
            }
        }

        static func create() -> Data? {
            var bytes = [UInt8](repeating: 0, count: byteCount)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                lError("SecRandomCopyBytes failed; cannot generate a database key")
                return nil
            }
            let key = Data(bytes)

            var attributes = baseQuery
            attributes[kSecAttrLabel as String] = label
            attributes[kSecValueData as String] = key

            let status = SecItemAdd(attributes as CFDictionary, nil)
            guard status == errSecSuccess else {
                // Notably `errSecDuplicateItem`, which means a key we could not read is already
                // there. Never delete-and-replace: that would orphan whatever it already encrypted.
                lError("Failed to store the database key in the keychain, status:", status)
                return nil
            }
            lInfo("Generated a new database key")
            return key
        }

        static var baseQuery: [String: Any] {
            [kSecClass as String: kSecClassGenericPassword,
             kSecAttrService as String: service,
             kSecAttrAccount as String: account]
        }
    }
}
