//
//  SnippetsEditorWindowController.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import AppKit
import SwiftUI

/// Replaces `CPYSnippetsEditorWindowController` and its xib — the last xib in the project.
///
/// The xib carried the window, a `CPYSplitView`, an `NSOutlineView` with a self-drawing
/// `CPYSnippetsEditorCell`, and six PNG toolbar buttons; all of that is now `SnippetsEditorView`.
/// What survives here is the window itself.
///
/// A SwiftUI `Window` scene was the obvious alternative and was rejected. `openWindow` is only
/// reachable from inside a scene, so `AppDelegate` — an `@objc` menu target — would have to repeat
/// the menu-item lookup and activation polling it already needs for `Settings`
/// (`showPreferenceWindow` / `bringSettingsWindowForward`), which is the most fragile code in the
/// app. `collectionBehavior` also has no declarative equivalent on macOS 14, and an `LSUIElement`
/// app needs `.canJoinAllSpaces` to open on the Space the user is actually looking at.
///
/// Built per open, not a singleton. The editor is a *detached* working copy of the folder graph
/// (see `SnippetsEditorStore`), so the one invariant that matters is that at most one exists at a
/// time — two windows would each mutate their own copy and overwrite each other's writes. That is
/// single-instance, not global access, and there is exactly one call site, so the reference lives
/// in `AppDelegate` and is dropped in `onWindowClose`. Every edit is committed on the spot
/// (`merge(in:)` per keystroke), so nothing is lost by throwing the store away on close.
final class SnippetsEditorWindowController: NSWindowController {

    private static let frameAutosaveName = "SnippetsEditorWindow"

    /// Fired after the window closes so the owner can release this controller, which is what makes
    /// the next open a fresh one — new store, new fetch, `AppEnvironment.current.box` read again.
    var onWindowClose: (() -> Void)?

    /// Owned here rather than declared `@State` inside the view so that `showWindow(_:)` can
    /// refresh it. `@Observable` (unlike `ObservableObject`) tracks reads of a plain `let`
    /// property just as well, so the views lose nothing by it.
    private let store = SnippetsEditorStore(box: AppEnvironment.current.box)

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = L10n.Snippets.Editor.title
        window.minSize = NSSize(width: 800, height: 600)
        window.collectionBehavior = .canJoinAllSpaces
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        // Restore *before* naming: `setFrameAutosaveName` writes the current frame under the new
        // name, which would clobber the entry being read. A singleton kept its frame in memory
        // across a close/reopen; a per-open window has to read it back from the defaults instead.
        if !window.setFrameUsingName(Self.frameAutosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)
        super.init(window: window)
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: SnippetsEditorView(store: store))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SnippetsEditorWindowController is not loaded from a nib")
    }

    /// `windowDidLoad` used to do the initial fetch. There is no nib now, so the fetch happens on
    /// show — which is also the re-show path when the menu is picked while the window is open.
    override func showWindow(_ sender: Any?) {
        store.reload()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(self)
    }
}

extension SnippetsEditorWindowController: NSWindowDelegate {

    /// Deferred by one turn of the run loop: the owner's reference is the last one, so releasing it
    /// here would deallocate this controller — and with it the window — while AppKit is still
    /// closing that window.
    func windowWillClose(_ notification: Notification) {
        LQueue.main.dispatchAsync { [onWindowClose] in onWindowClose?() }
    }
}
