//
//  File.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Aphro on 10/10/23.
//
//  Copyright © 2015-2023 Clipy Project.
//

import Foundation
import AppKit

// Credits to https://github.com/sindresorhus/KeyboardShortcuts
final class RunLoopLocalEventMonitor {
    private let runLoopMode: RunLoop.Mode
    private let callback: (NSEvent) -> NSEvent?
    private let observer: CFRunLoopObserver

    init(
        runLoopMode: RunLoop.Mode,
        callback: @escaping (NSEvent) -> NSEvent?
    ) {
        self.runLoopMode = runLoopMode
        self.callback = callback

        self.observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.beforeSources.rawValue, true, 0) { _, _ in
            // Pull all events from the queue and handle the ones matching the given types.
            // As non-processes events are redispatched we have to gather them first before processing to avoid infinite loops.
            var eventsToHandle = [NSEvent]()

            // Note: Non-processed events are redispatched and may therefore be out of order with respect to other events.
            //       Even though we are only interested in keydown events we deque the keyUp events as well to preserve their order.
            while let eventToHandle = NSApp.nextEvent(
                matching: [.keyDown, .keyUp], until: nil, inMode: .default, dequeue: true
            ) {
                eventsToHandle.append(eventToHandle)
            }

            // Iterate over the gathered events, instead of doing it directly in the `while` loop,
            // to avoid potential infinite loops caused by re-retrieving undiscarded events.
            for eventToHandle in eventsToHandle {
                if let callbackEvent = callback(eventToHandle) {
                    NSApp.postEvent(callbackEvent, atStart: false)
                }
            }
        }
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Self {
        CFRunLoopAddObserver(RunLoop.current.getCFRunLoop(), observer, CFRunLoopMode(runLoopMode.rawValue as CFString))
        return self
    }

    func stop() {
        CFRunLoopRemoveObserver(RunLoop.current.getCFRunLoop(), observer, CFRunLoopMode(runLoopMode.rawValue as CFString))
    }
}
