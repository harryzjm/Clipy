//
//  ClipyBox+Signal.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import RxSwift

extension ClipyBox {

    /// Emits the clipboard history window whenever it changes.
    func observeClips(ascending: Bool,
                      limit: Int?,
                      observeOn scheduler: ImmediateSchedulerType? = nil) -> Observable<[CPYClip]> {
        clipTransactionSignal(observeOn: scheduler) { observer, transaction in
            let view = try MutableClipListView(service: transaction, ascending: ascending, limit: limit)

            let tracker = transaction.service.viewTracker
            let queue = transaction.service.queue

            let (index, signal) = tracker.addView(view)
            observer.onNext(view.clips.map { $0.toClip })

            let disposable = signal.subscribe { immutable in
                observer.onNext(immutable.clips.map { $0.toClip })
            }

            return Disposables.create {
                disposable.dispose()
                queue.dispatch {
                    tracker.removeView(index)
                }
            }
        }
    }
}

// MARK: - Plumbing
fileprivate extension ClipyBox {

    func clipTransactionSignal<T>(userInteractive: Bool = false,
                                  observeOn scheduler: ImmediateSchedulerType? = nil,
                                  file: String = #file,
                                  function: String = #function,
                                  line: Int = #line,
                                  _ f: @escaping (AnyObserver<T>, ClipServiceTransaction) throws -> Disposable) -> Observable<T> {
        transactionSignal(userInteractive: userInteractive,
                          observeOn: scheduler,
                          service: clip,
                          file: file,
                          function: function,
                          line: line,
                          f)
    }
}
