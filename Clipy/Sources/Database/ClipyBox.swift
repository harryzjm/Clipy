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

    static let shared = ClipyBox()

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

    override init(path: String = ClipyBox.databaseDirectory()) {
        _ = CPYUtilities.prepareSaveToPath(path)

        let mmkvRoot = (path as NSString).appendingPathComponent("mmkv")
        // Must run before any `MMKV(mmapID:rootPath:)`.
        MMKV.initialize(rootDir: mmkvRoot)
        guard let store = MMKV(mmapID: "clipyBox.mmkv", rootPath: mmkvRoot) else {
            fatalError("Failed to open MMKV at \(mmkvRoot)")
        }
        self.store = store

        super.init(path: path)
    }

    deinit {
        store.clearMemoryCache()
    }

    /// Opens every database eagerly so migrations run at a known point in the launch sequence.
    func setup() {
        _ = clip.clipDb
        _ = snippet.snippetDb
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
