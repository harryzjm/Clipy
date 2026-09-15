//
//  PreferenceControls.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI

/// A labelled integer field with a stepper and a trailing unit, replacing the
/// `NSTextField` + `NSNumberFormatter` + unit-label triples the preference xibs used.
struct NumberRow: View {

    let title: String
    let unit: String
    let range: ClosedRange<Int>
    @Binding var value: Int

    init(_ title: String, unit: String, range: ClosedRange<Int>, value: Binding<Int>) {
        self.title = title
        self.unit = unit
        self.range = range
        self._value = value
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField(title, value: $value, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                Stepper(title, value: $value, in: range)
                    .labelsHidden()
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
