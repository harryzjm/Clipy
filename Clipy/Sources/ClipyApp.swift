//
//  ClipyApp.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

/// Application entry point.
///
/// Clipy used to launch through `MainMenu.xib` (`NSMainNibFile`), whose only real job was to
/// instantiate `AppDelegate` and provide the standard Edit menu. The SwiftUI lifecycle covers
/// both: `@NSApplicationDelegateAdaptor` owns the delegate and SwiftUI synthesises the standard
/// menu bar, which an `LSUIElement` app still needs for ⌘X/⌘C/⌘V/⌘A/⌘Z key equivalents.
///
/// `Settings` is deliberately the only scene. It never opens on its own, so the launch behaviour
/// of this background app is unchanged. The snippets editor keeps its own `NSWindowController`.
@main
struct ClipyApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            PreferencesRootView()
        }
    }
}
