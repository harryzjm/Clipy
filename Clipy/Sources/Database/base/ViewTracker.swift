//
//  ViewTracker.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation
import RxSwift
import RxCocoa

/// Holds the live clip views and replays each committed transaction into them.
///
/// Corresponds to `ServiceBox/base/SessionViewTracker.swift`.
final class ClipViewTracker {

    typealias Record = (MutableClipListView, PublishRelay<MutableClipListView.Immutable>)

    private let views = Bag<Record>()

    func updateViews(currentTransaction: ClipServiceTransaction, change: ClipChangeSet) {
        for (view, pipe) in views.copyItems() where view.replay(service: currentTransaction, change: change) {
            pipe.accept(view.immutableView())
        }
    }

    func addView(_ view: MutableClipListView) -> (Bag<Record>.Index, Observable<MutableClipListView.Immutable>) {
        let record: Record = (view, PublishRelay<MutableClipListView.Immutable>())
        let index = views.add(record)
        return (index, record.1.asObservable())
    }

    func removeView(_ index: Bag<Record>.Index) {
        views.remove(index)
    }
}
