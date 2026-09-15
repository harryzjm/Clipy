//
//  Atomic.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2024 Clipy Project.
//

import Foundation

/// A lock-protected box around a value.
///
/// Ported from the `ServiceBox` reference implementation, where it comes from `LFUtils`.
/// Used by `ComponentServiceInternal` to guard transaction gating state.
final class Atomic<Value> {

    private var value: Value
    private let lock = NSLock()

    init(value: Value) {
        self.value = value
    }

    /// Replaces the value and returns the previous one.
    @discardableResult
    func swap(_ newValue: Value) -> Value {
        lock.lock(); defer { lock.unlock() }
        let previous = value
        value = newValue
        return previous
    }

    /// Reads the value under the lock.
    func with<T>(_ block: (Value) -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return block(value)
    }

    /// Transforms the value under the lock and returns the new one.
    @discardableResult
    func modify(_ block: (Value) -> Value) -> Value {
        lock.lock(); defer { lock.unlock() }
        value = block(value)
        return value
    }
}
