//
//  ExcludeAppPane.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

/// Replaces `CPYExcludeAppPreferenceViewController` and its xib, including the hand-rolled
/// `NSTableViewDataSource` that read straight out of `ExcludeAppService.applications`.
struct ExcludeAppPane: View {

    @State private var store = ExcludeAppStore()
    @State private var selection: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exclude these applications:")
                .font(.headline)

            List(store.applications, selection: $selection) { app in
                Text(app.name)
            }
            .listStyle(.inset)
            .alternatingRowBackgrounds()
            .border(.separator)

            HStack(spacing: 8) {
                Button {
                    store.addApplications()
                } label: {
                    Label(L10n.ExcludedApps.addButton, systemImage: "plus")
                }

                Button {
                    store.delete(identifiers: selection)
                    selection.removeAll()
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(selection.isEmpty)
            }
            .clipyGlassButtonStyle()
        }
        .padding(20)
    }
}
