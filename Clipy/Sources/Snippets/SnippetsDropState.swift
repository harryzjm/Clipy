//
//  SnippetsDropState.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import AppKit
import Foundation
import Observation
import SwiftUI

/// The row a drag is currently over, and what a drop on it would do.
struct SnippetsDropTarget: Equatable {
    let selection: SnippetsSelection
    let indicator: SnippetsDropIndicator
}

/// What a drag is carrying, as the row that started it knew it.
enum SnippetsDragPayload: Equatable {
    case folder(String)
    case snippet(String)
}

/// Where the sidebar's drag feedback lives, for exactly as long as a drag lasts.
///
/// One target for the whole list rather than a `@State` per row. A row's own state survives the
/// list reordering underneath it and is only cleared by the `dropExited` that row happens to
/// receive — so a drag that ended anywhere else left its insertion line behind. Held here,
/// pointing at one row at a time, a stale line is not expressible: setting a new target clears
/// the old one, and the drop clears the lot.
@Observable
final class SnippetsDropState {

    /// The sidebar `List`'s coordinate space, which the rows measure themselves in.
    static let coordinateSpace = "SnippetsSidebarRows"

    private(set) var target: SnippetsDropTarget?

    /// What this window is dragging right now.
    ///
    /// `.onDrag`'s closure runs at the moment the drag begins, so the payload is known here
    /// before any drop target sees it — which is what lets `performDrop` apply the move
    /// synchronously instead of waiting on `loadTransferable`, and lets a row refuse to draw an
    /// insertion line under the very row being dragged.
    private(set) var dragged: SnippetsDragPayload?

    /// Spring-loading. Not observed: only the timer's *effect* (a folder expanding) is drawn.
    @ObservationIgnored private var hoverExpandTimer: Timer?
    /// See `startDragWatchdog()`.
    @ObservationIgnored private var dragWatchdog: Timer?

    /// Row frames in `coordinateSpace`. Deliberately **not** observed: these are written from
    /// layout, and a write that invalidated the views doing the measuring would loop.
    @ObservationIgnored private var frames: [SnippetsSelection: CGRect] = [:]

    /// Records the drag this window just started.
    func begin(_ payload: SnippetsDragPayload) {
        clear()
        dragged = payload
        // Started here rather than left to the first `hover()`: a drag that never crosses a
        // valid drop row (dropped on empty space, or over a row that always refuses it) would
        // otherwise never schedule the watchdog that is what notices the mouse button went up.
        startDragWatchdog()
    }

    func isDragged(_ selection: SnippetsSelection) -> Bool {
        switch (dragged, selection) {
        case let (.folder(dragged), .folder(identifier)),
             let (.snippet(dragged), .snippet(identifier)):
            return dragged == identifier
        default:
            return false
        }
    }

    func record(_ frame: CGRect, for selection: SnippetsSelection) {
        frames[selection] = frame
    }

    /// The empty space between two rows, whichever order they are in, or nil if either has not
    /// been laid out. `List` insets its rows' content, so this is bigger than it looks in the
    /// view tree — which is exactly why it is measured instead of assumed.
    func gap(between one: SnippetsSelection, and other: SnippetsSelection) -> CGFloat? {
        guard let first = frames[one], let second = frames[other] else { return nil }

        let gap = first.minY < second.minY ? second.minY - first.maxY : first.minY - second.maxY
        return max(0, gap)
    }

    func indicator(for selection: SnippetsSelection) -> SnippetsDropIndicator? {
        guard let target, target.selection == selection else { return nil }
        return target.indicator
    }

    /// The pointer is over `selection`, and a drop there would do `indicator`.
    ///
    /// `springLoad` is what hovering here long enough should do — opening a collapsed folder, in
    /// practice. It arrives as a closure rather than a folder identifier plus a store, because
    /// what is worth expanding is the drop delegate's business, and deciding it there keeps this
    /// type to the one thing it is: what the sidebar is drawing while a drag is in flight.
    ///
    /// `@autoclosure` because this fires on every `dropUpdated` while the pointer sits still over
    /// a row — building the actual spring-load closure is wasted work on every one of those calls
    /// except the one where the target actually changes, which is the only case that reaches it.
    func hover(_ indicator: SnippetsDropIndicator,
               over selection: SnippetsSelection,
               springLoad: @autoclosure () -> (() -> Void)? = nil) {
        let next = SnippetsDropTarget(selection: selection, indicator: indicator)
        guard next != target else { return }

        target = next
        scheduleHoverExpand(springLoad())
        startDragWatchdog()
    }

    /// The pointer left `selection`. Only the indicator is this row's to give up — `dragged` is
    /// the whole drag session's payload, and is only ever wiped by `clear()`. Also guards against
    /// SwiftUI delivering the next row's `dropEntered` before this row's `dropExited`: if that
    /// already moved `target` elsewhere, this call must not take it back.
    func exit(_ selection: SnippetsSelection) {
        guard target?.selection == selection else { return }
        target = nil
        hoverExpandTimer?.invalidate()
        hoverExpandTimer = nil
    }

    func clear() {
        target = nil
        dragged = nil
        hoverExpandTimer?.invalidate()
        hoverExpandTimer = nil
        dragWatchdog?.invalidate()
        dragWatchdog = nil
    }

    deinit {
        hoverExpandTimer?.invalidate()
        dragWatchdog?.invalidate()
    }

    /// The indicator's real lifetime is the drag session's, and SwiftUI does not reliably end
    /// one: a drag cancelled with Escape, or released right as the pointer crosses out of a row,
    /// delivers neither `dropExited` nor `performDrop`, and the last insertion line stays on
    /// screen until something else happens to clear it.
    ///
    /// The mouse button is the ground truth for "a drag is still in flight", so poll it for as
    /// long as there is a target to clean up — which is only ever during a drag. `.common` mode
    /// because the main dispatch queue is not a safe bet while a drag is tracking.
    private func startDragWatchdog() {
        guard dragWatchdog == nil else { return }

        // Loose on purpose: `dropExited` and `performDrop` do the clearing in every case seen in
        // practice, and this only has to catch the ones SwiftUI drops on the floor.
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard NSEvent.pressedMouseButtons == 0 else { return }
            self?.clear()
        }
        RunLoop.main.add(timer, forMode: .common)
        dragWatchdog = timer
    }

    /// Spring-loading: hovering long enough over a collapsed folder opens it, so a cross-folder
    /// drop can be positioned instead of only appended. Nothing ever auto-*collapses* — that is
    /// how folders end up flickering open and shut as the pointer crosses them.
    ///
    /// `RunLoop.main` in `.common` for the same reason `MainRunLoopScheduler` exists — nothing
    /// here should bet on the main dispatch queue being drained while a drag is tracking.
    private func scheduleHoverExpand(_ springLoad: (() -> Void)?) {
        hoverExpandTimer?.invalidate()
        hoverExpandTimer = nil

        guard let springLoad else { return }

        let timer = Timer(timeInterval: 0.6, repeats: false) { _ in springLoad() }
        RunLoop.main.add(timer, forMode: .common)
        hoverExpandTimer = timer
    }
}
