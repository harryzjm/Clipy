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
final class SnippetsEditorWindowController: NSWindowController {

    static let shared = SnippetsEditorWindowController()

    /// Owned here rather than declared `@State` inside the view so that `showWindow(_:)` can
    /// refresh it. `@Observable` (unlike `ObservableObject`) tracks reads of a plain `let`
    /// property just as well, so the views lose nothing by it.
    private let store = SnippetsEditorStore()

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = "Snippet Editor"
        window.minSize = NSSize(width: 800, height: 600)
        window.collectionBehavior = .canJoinAllSpaces
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SnippetsEditorWindow")
        window.center()
        super.init(window: window)
        window.contentViewController = NSHostingController(rootView: SnippetsEditorView(store: store))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SnippetsEditorWindowController is not loaded from a nib")
    }

    /// `windowDidLoad` used to do the initial fetch. There is no nib now, and the hosting
    /// controller outlives a close/reopen cycle, so refresh on every show instead.
    override func showWindow(_ sender: Any?) {
        store.reload()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(self)
    }
}
