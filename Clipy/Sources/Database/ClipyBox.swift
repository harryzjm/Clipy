//
//  ClipyBox.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import RxSwift
import MMKV

final class ClipyBox: StorageBox {

    let store: MMKV

    lazy private(set) var clip: ClipComponentService = {
        let service = ClipComponentService()
        service.box = self
        return service
    }()

    lazy private(set) var snippet: SnippetComponentService = {
        let service = SnippetComponentService()
        service.box = self
        return service
    }()

    static func databaseDirectory() -> String {
        (CPYUtilities.applicationSupportFolder() as NSString).appendingPathComponent("db")
    }

    /// `secretCode` has no default on purpose: the installation key belongs to `SecretService`,
    /// which `Environment` resolves once and hands down here. Making it explicit is what keeps the
    /// databases and the payload files provably under the same key, and it is how tests hand in
    /// their own without anything touching the developer's keychain.
    ///
    /// `recovery` defaults to nil for the mirror-image reason: deleting a database nobody can
    /// read is the app's call to put to the user, so `Environment` passes one in and nothing
    /// headless — tests included — ends up with a window on screen by omission.
    ///
    /// `override` only because this now matches `StorageBox.init(path:secretCode:recovery:)`
    /// exactly; the `path` default is what this adds.
    override init(path: String = ClipyBox.databaseDirectory(),
                  secretCode: Data?,
                  recovery: DatabaseRecovery? = nil) {
        _ = CPYUtilities.prepareSaveToPath(path)
        lInfo("DB:", path, secretCode == nil ? "(plaintext)" : "(encrypted)")

        let mmkvRoot = (path as NSString).appendingPathComponent("mmkv")
        // Must run before any `MMKV(mmapID:rootPath:)`.
        MMKV.initialize(rootDir: mmkvRoot)
        // The store holds only the schema versions, but it is encrypted with the same key so
        // that nothing about the databases sits beside them in the clear. `aes256` raises the
        // key limit from 16 bytes to 32, which is what `SecretService` generates.
        let opened = secretCode.flatMap { MMKV(mmapID: "clipyBox.mmkv", cryptKey: $0, aes256: true, rootPath: mmkvRoot) }
            ?? MMKV(mmapID: "clipyBox.mmkv", rootPath: mmkvRoot)
        guard let opened else {
            fatalError("Failed to open MMKV at \(mmkvRoot)")
        }
        self.store = opened

        super.init(path: path, secretCode: secretCode, recovery: recovery)
    }

    deinit {
        store.clearMemoryCache()
    }

    func setCanBeginTransactions(_ value: Bool) {
        clip.setCanBeginTransactions(value)
        snippet.setCanBeginTransactions(value)
    }
}

// MARK: - Transaction
extension ClipyBox {
    func clipTransaction<T>(userInteractive: Bool = false,
                            ignoreDisabled: Bool = false,
                            ignoreTransaction: Bool = false,
                            observeOn scheduler: ImmediateSchedulerType? = nil,
                            file: String = #file,
                            function: String = #function,
                            line: Int = #line,
                            _ f: @escaping (ClipServiceTransaction) throws -> T) -> Observable<T> {
        transaction(userInteractive: userInteractive,
                    ignoreDisabled: ignoreDisabled,
                    ignoreTransaction: ignoreTransaction,
                    observeOn: scheduler,
                    service: clip,
                    file: file,
                    function: function,
                    line: line,
                    f)
    }

    func snippetTransaction<T>(userInteractive: Bool = false,
                               ignoreDisabled: Bool = false,
                               ignoreTransaction: Bool = false,
                               observeOn scheduler: ImmediateSchedulerType? = nil,
                               file: String = #file,
                               function: String = #function,
                               line: Int = #line,
                               _ f: @escaping (SnippetServiceTransaction) throws -> T) -> Observable<T> {
        transaction(userInteractive: userInteractive,
                    ignoreDisabled: ignoreDisabled,
                    ignoreTransaction: ignoreTransaction,
                    observeOn: scheduler,
                    service: snippet,
                    file: file,
                    function: function,
                    line: line,
                    f)
    }
}
