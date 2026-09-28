//
//  WindowCloseObserver.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import SwiftUI

/// Calls `onClose` when the window hosting it is about to close.
///
/// `onDisappear` is not a substitute: in the Preferences window it also fires whenever the
/// sidebar switches panes. This listens for the window's own `willCloseNotification`, and follows
/// the view if SwiftUI moves it to another window.
struct WindowCloseObserver: NSViewRepresentable {

    let onClose: () -> Void

    func makeNSView(context: Context) -> ObserverView {
        ObserverView()
    }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.onClose = onClose
    }

    final class ObserverView: NSView {
        var onClose: (() -> Void)?
        private var token: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard let window else { return }
            token = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                                           object: window,
                                                           queue: .main) { [weak self] _ in
                self?.onClose?()
            }
        }

        deinit {
            stopObserving()
        }

        private func stopObserving() {
            if let token {
                NotificationCenter.default.removeObserver(token)
            }
            token = nil
        }
    }
}
