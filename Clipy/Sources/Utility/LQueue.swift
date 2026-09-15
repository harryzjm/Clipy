//
//  LQueue.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation

/// A serial `DispatchQueue` wrapper that can tell whether the caller is already running on it.
///
/// Ported from the `ServiceBox` reference implementation, where it comes from `LFUtils`.
/// `ComponentService` funnels every database access through one of these so that a
/// `begin`/`commit` pair spanning multiple `Database` objects stays coherent.
final class LQueue {

    private static let specificKey = DispatchSpecificKey<ObjectIdentifier>()

    let queue: DispatchQueue

    static let main = LQueue(wrapQueue: .main)

    init(wrapQueue: DispatchQueue) {
        self.queue = wrapQueue
        wrapQueue.setSpecific(key: LQueue.specificKey, value: ObjectIdentifier(wrapQueue))
    }

    convenience init(label: String, qos: DispatchQoS = .default) {
        self.init(wrapQueue: DispatchQueue(label: label, qos: qos))
    }

    /// True when the current execution context is this queue.
    func isCurrent() -> Bool {
        DispatchQueue.getSpecific(key: LQueue.specificKey) == ObjectIdentifier(queue)
    }

    /// Runs inline when already on this queue, otherwise asynchronously.
    func dispatch(_ block: @escaping () -> Void) {
        if isCurrent() {
            block()
        } else {
            queue.async(execute: block)
        }
    }

    func dispatchAsync(_ block: @escaping () -> Void) {
        queue.async(execute: block)
    }

    func dispatchAsyncWithQos(qos: DispatchQoS, _ block: @escaping () -> Void) {
        queue.async(group: nil, qos: qos, flags: [], execute: block)
    }
}
