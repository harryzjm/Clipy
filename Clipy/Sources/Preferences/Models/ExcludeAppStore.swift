//
//  ExcludeAppStore.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI
import UniformTypeIdentifiers

/// Backing store for the Excluded Apps pane.
///
/// `ExcludeAppService` already owns persistence (it archives into `kCPYExcludeApplications` on
/// every mutation), so this only mirrors its array into observable state for the list.
@Observable
final class ExcludeAppStore {

    private(set) var applications: [CPYAppInfo] = []

    init() {
        reload()
    }

    func reload() {
        applications = AppEnvironment.current.excludeAppService.applications
    }

    /// Ported from `CPYExcludeAppPreferenceViewController.addAppButtonTapped(_:)`.
    func addApplications() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.application]
        openPanel.allowsMultipleSelection = true
        openPanel.resolvesAliases = true
        openPanel.prompt = L10n.add
        let directories = NSSearchPathForDirectoriesInDomains(.applicationDirectory, .localDomainMask, true)
        openPanel.directoryURL = URL(fileURLWithPath: directories.first ?? NSHomeDirectory())

        guard openPanel.runModal() == .OK else { return }

        openPanel.urls.forEach { url in
            guard let bundle = Bundle(url: url), let info = bundle.infoDictionary else { return }
            guard let appInfo = CPYAppInfo(info: info as [String: AnyObject]) else { return }
            AppEnvironment.current.excludeAppService.add(with: appInfo)
        }
        reload()
    }

    func delete(identifiers: Set<String>) {
        guard !identifiers.isEmpty else { return }
        applications
            .filter { identifiers.contains($0.identifier) }
            .forEach { AppEnvironment.current.excludeAppService.delete(with: $0) }
        reload()
    }
}

extension CPYAppInfo: Identifiable {
    var id: String { identifier }
}
