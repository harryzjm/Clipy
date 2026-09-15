//
//  StoreTypesStore.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

/// Backing store for the Type pane.
///
/// The old pane bound its checkboxes to an `@objc NSMutableDictionary` on the view controller and
/// only flushed it to `kCPYPrefStoreTypesKey` when the preferences window closed. This writes on
/// every toggle instead, which `ClipService` — already observing that key — picks up immediately.
@Observable
final class StoreTypesStore {

    /// Driven by `CPYClipData.availableTypesString` so the pane can never drift out of sync with
    /// the types `ClipService` actually checks. The old xib hard-coded seven checkboxes and
    /// omitted PNG, leaving it permanently enabled with no way to turn it off.
    let types: [String] = CPYClipData.availableTypesString

    private var storage: [String: NSNumber]

    init() {
        let defaults = AppEnvironment.current.defaults
        storage = defaults.object(forKey: Constants.UserDefaults.storeTypes) as? [String: NSNumber] ?? [:]
    }

    func title(for type: String) -> String {
        switch type {
        case "String": return "Plain Text"
        case "RTF": return "Rich Text Format (RTF)"
        case "RTFD": return "Rich Text Format Directory (RTFD)"
        case "PNG": return "PNG Image"
        case "TIFF": return "TIFF Image"
        default: return type
        }
    }

    func binding(for type: String) -> Binding<Bool> {
        Binding(
            get: { self.storage[type]?.boolValue ?? false },
            set: { self.setEnabled($0, for: type) }
        )
    }

    private func setEnabled(_ enabled: Bool, for type: String) {
        storage[type] = NSNumber(value: enabled)
        let defaults = AppEnvironment.current.defaults
        defaults.set(storage, forKey: Constants.UserDefaults.storeTypes)
        defaults.synchronize()
    }
}
