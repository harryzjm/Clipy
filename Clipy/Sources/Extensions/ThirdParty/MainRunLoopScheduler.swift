//
//  MainRunLoopScheduler.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by hares on 2026/9/16.
//
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation
import AppKit
import RxSwift

/// Main thread scheduler that keeps delivering while an `NSMenu` is tracking.
///
/// `MainScheduler` and `ConcurrentMainScheduler` hop threads through `DispatchQueue.main`, and the
/// main queue is not drained while a menu runs its nested tracking loop: whatever a background
/// queue hands over after `popUp(...)` only arrives once the menu closes. Run loop blocks do run
/// during tracking as long as they are registered for the mode the loop spins in — the same escape
/// hatch `TextFieldContentView.set(query:)` and `RunLoopLocalEventMonitor` already use for keys.
final class MainRunLoopScheduler: ImmediateSchedulerType {

    static let instance = MainRunLoopScheduler()

    /// `.common` covers the default and modal modes, `.eventTracking` is the menu tracking one.
    private static let modes = [RunLoop.Mode.common.rawValue, RunLoop.Mode.eventTracking.rawValue] as CFArray

    /// Runs `block` on the main thread — inline when already there, through a run loop block
    /// otherwise, so that it still lands while a menu is tracking.
    static func perform(_ block: @escaping () -> Void) {
        guard !Thread.isMainThread else { return block() }

        let runLoop = CFRunLoopGetMain()
        CFRunLoopPerformBlock(runLoop, modes, block)
        // `CFRunLoopPerformBlock` on its own does not wake a sleeping run loop.
        CFRunLoopWakeUp(runLoop)
    }

    func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
        guard !Thread.isMainThread else { return action(state) }

        let cancel = SingleAssignmentDisposable()
        Self.perform {
            guard !cancel.isDisposed else { return }
            cancel.setDisposable(action(state))
        }
        return cancel
    }
}
