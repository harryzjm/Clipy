//
//  Bag.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation

/// An unordered, thread-safe collection whose elements are addressed by an opaque index
/// that stays valid across insertions and removals.
///
/// Ported from the `ServiceBox` reference implementation, where it comes from `LFUtils`.
/// `ViewTracker` uses it to hold registered mutable views together with their signal pipes,
/// so a view can deregister itself on dispose without disturbing the others.
final class Bag<Element> {

    typealias Index = Int

    private var items: [Index: Element] = [:]
    private var nextIndex: Index = 0
    private let lock = NSLock()

    init() {}

    @discardableResult
    func add(_ element: Element) -> Index {
        lock.lock(); defer { lock.unlock() }
        let index = nextIndex
        nextIndex += 1
        items[index] = element
        return index
    }

    func remove(_ index: Index) {
        lock.lock(); defer { lock.unlock() }
        items.removeValue(forKey: index)
    }

    /// Snapshot of the current elements, safe to iterate while the bag mutates.
    func copyItems() -> [Element] {
        lock.lock(); defer { lock.unlock() }
        return Array(items.values)
    }

    var isEmpty: Bool {
        lock.lock(); defer { lock.unlock() }
        return items.isEmpty
    }
}
