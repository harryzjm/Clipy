//
//  SnippetComponentService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import RxSwift

/// Owns `snippet.db` and the serial queue every snippet access runs on.
final class SnippetComponentService: ComponentService {

    let name = "Snippet"
    weak var box: ClipyBox!

    lazy fileprivate(set) var snippetDb: SnippetDB = {
        .init(rootPath: box.path, name: "snippet.db", secretCode: box.secretCode, store: box.store, recovery: box.recovery)
    }()

    let inter = ComponentServiceInternal()
    let queue = LQueue(label: "com.clipy.box.snippet")
    let observeScheduler: ImmediateSchedulerType = SerialDispatchQueueScheduler(qos: .default,
                                                                               internalSerialQueueName: "com.clipy.box.snippet.observe")
}

struct SnippetServiceTransaction: Transaction {

    weak var service: SnippetComponentService!

    init(service: SnippetComponentService!) {
        self.service = service
    }

    var snippetDb: SnippetDB {
        service.snippetDb
    }

    func begin() throws {
        try snippetDb.begin()
    }

    func commit() throws {
        try snippetDb.commit()
    }

    func rollback() throws {
        try snippetDb.rollback()
    }

    func vacuum() throws {
        try snippetDb.vacuum()
    }
}
