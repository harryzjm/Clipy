//
//  StorageBox.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import QuartzCore
import RxSwift

/// Generic Rx transaction runner shared by every component service.
///
/// Ported from `ServiceBox/db/StorageBox.swift`. Work is dispatched onto the owning service's
/// serial queue and results are delivered on that service's observe scheduler unless the
/// caller overrides it.
class StorageBox {

    #if DEBUG
    static let threshold: CFTimeInterval = 0.1
    #else
    static let threshold: CFTimeInterval = 1
    #endif

    let path: String
    /// SQLCipher key for every database in this box. `nil` runs them unencrypted.
    let secretCode: Data?
    /// Asked before a database in this box that will not open is deleted and rebuilt. It sits
    /// beside `secretCode` because that is what it answers for: one key covers every file here,
    /// so a key that does not match the files breaks all of them at once.
    let recovery: DatabaseRecovery?

    init(path: String, secretCode: Data?, recovery: DatabaseRecovery? = nil) {
        self.path = path
        self.secretCode = secretCode
        self.recovery = recovery
    }
}

// MARK: - Transaction
extension StorageBox {
    func transaction<V, S: ComponentService, T: Transaction>(userInteractive: Bool,
                                                             ignoreDisabled: Bool,
                                                             ignoreTransaction: Bool,
                                                             observeOn scheduler: ImmediateSchedulerType? = nil,
                                                             service: S,
                                                             file: String,
                                                             function: String,
                                                             line: Int,
                                                             _ f: @escaping (T) throws -> V) -> Observable<V> where T.T == S {
        return Observable.create { [weak service] observer in
            guard let service = service else {
                observer.onCompleted()
                return Disposables.create()
            }
            let work: () -> Void = {
                service.beginInternalTransaction(ignoreDisabled: ignoreDisabled) {
                    let begin = CACurrentMediaTime()
                    do {
                        let result = try service.internalTransaction(ignoreTransaction, f: f)
                        let diff = CACurrentMediaTime() - begin
                        if diff > Self.threshold {
                            lWarning("StorageBox slow transaction", service.name, String(format: "%.2fs", diff),
                                     (file as NSString).lastPathComponent, function, line)
                        }
                        observer.onNext(result)
                        observer.onCompleted()
                    } catch {
                        lError("StorageBox transaction error", service.name, error,
                               (file as NSString).lastPathComponent, function, line)
                        observer.onError(error)
                    }
                }
            }
            if service.queue.isCurrent() {
                work()
            } else if userInteractive {
                service.queue.dispatchAsyncWithQos(qos: .userInteractive, work)
            } else {
                service.queue.dispatchAsync(work)
            }
            return Disposables.create()
        }
        .observe(on: scheduler ?? service.observeScheduler)
    }

    /// Like `transaction`, but the closure returns a `Disposable` and the sequence never completes.
    /// Used by the change signals in `ClipyBox+Signal`.
    func transactionSignal<V, S: ComponentService, T: Transaction>(userInteractive: Bool,
                                                                   observeOn scheduler: ImmediateSchedulerType? = nil,
                                                                   service: S,
                                                                   file: String,
                                                                   function: String,
                                                                   line: Int,
                                                                   _ f: @escaping (AnyObserver<V>, T) throws -> Disposable) -> Observable<V> where T.T == S {
        return Observable.create { [weak service] observer in
            guard let service = service else {
                observer.onCompleted()
                return Disposables.create()
            }

            let disposable = CompositeDisposable()
            let work: () -> Void = {
                service.beginInternalTransaction {
                    do {
                        _ = try service.internalTransaction(false) { (transaction: T) in
                            _ = disposable.insert(try f(observer, transaction))
                        }
                    } catch {
                        lError("StorageBox signal error", service.name, error,
                               (file as NSString).lastPathComponent, function, line)
                        observer.onError(error)
                    }
                }
            }
            if service.queue.isCurrent() {
                work()
            } else if userInteractive {
                service.queue.dispatchAsyncWithQos(qos: .userInteractive, work)
            } else {
                service.queue.dispatchAsync(work)
            }
            return disposable
        }
        .observe(on: scheduler ?? service.observeScheduler)
    }
}
