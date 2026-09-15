//
//  ComponentService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import RxSwift

/// A unit of work run against one `ComponentService`'s databases.
///
/// Ported from `ServiceBox/base/ComponentService.swift`. `beforeCommit()` is the hook where a
/// component turns the deltas its DAO recorded during the transaction into change signals —
/// this is what replaces Realm's `NotificationToken`.
protocol Transaction {
    associatedtype T: ComponentService
    var service: T! { get set }
    init(service: T!)

    func begin() throws
    func afterBegin() throws
    func beforeCommit() throws
    func commit() throws
    func rollback() throws
    func vacuum() throws
}

extension Transaction {
    func afterBegin() throws {
    }

    func beforeCommit() throws {
    }
}

struct ComponentServiceInternal {
    let isInTransaction = Atomic<Bool>(value: false)
    let canBeginTransactionsValue = Atomic<Bool>(value: true)
    let queuedInternalTransactions = Atomic<[() -> Void]>(value: [])
}

/// One serial queue plus the databases it owns.
protocol ComponentService: AnyObject {
    var name: String { get }
    var box: ClipyBox! { get set }

    var inter: ComponentServiceInternal { get }

    var queue: LQueue { get }
    var observeScheduler: ImmediateSchedulerType { get }
}

extension ComponentService {
    func internalTransaction<T, M: Transaction>(_ ignoreTransaction: Bool, f: (M) throws -> T) throws -> T where M.T == Self {
        inter.isInTransaction.swap(true)
        defer { inter.isInTransaction.swap(false) }

        let transaction = M(service: self)

        do {
            if !ignoreTransaction {
                try transaction.begin()
            }
            try transaction.afterBegin()
            let result = try f(transaction)
            try transaction.beforeCommit()
            if !ignoreTransaction {
                try transaction.commit()
            }
            return result
        } catch {
            if !ignoreTransaction {
                try transaction.rollback()
            }
            throw error
        }
    }

    func beginInternalTransaction(ignoreDisabled: Bool = false, _ f: @escaping () -> Void) {
        assert(queue.isCurrent())
        if ignoreDisabled || inter.canBeginTransactionsValue.with({ $0 }) {
            f()
        } else {
            inter.queuedInternalTransactions.modify { $0 + [f] }
        }
    }

    /// Gates new transactions. Flipping back to `true` drains whatever queued up while disabled.
    func setCanBeginTransactions(_ value: Bool) {
        queue.dispatch {
            let previous = self.inter.canBeginTransactionsValue.swap(value)
            if previous != value && value {
                let fs = self.inter.queuedInternalTransactions.swap([])
                fs.forEach { $0() }
            }
        }
    }
}
