//
//  TypePane.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

/// Replaces `CPYTypePreferenceViewController` and its xib.
struct TypePane: View {

    @State private var store = StoreTypesStore()

    var body: some View {
        Form {
            Section("Store the following clipboard types") {
                ForEach(store.types, id: \.self) { type in
                    Toggle(store.title(for: type), isOn: store.binding(for: type))
                }
            }
        }
        .formStyle(.grouped)
    }
}
