//
//  ShortcutRecorder.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI
import KeyHolder
import Magnet

/// SwiftUI wrapper around KeyHolder's `RecordView`.
///
/// KeyHolder (via Magnet and Sauce) handles keyboard-layout mapping, so the recorder is wrapped
/// rather than reimplemented. The delegate callbacks mirror what
/// `CPYShortcutsPreferenceViewController` did.
struct ShortcutRecorder: NSViewRepresentable {

    var keyCombo: KeyCombo?
    var onChange: (KeyCombo?) -> Void

    func makeNSView(context: Context) -> RecordView {
        let recordView = RecordView(frame: .zero)
        recordView.delegate = context.coordinator
        recordView.keyCombo = keyCombo
        recordView.cornerRadius = 6
        return recordView
    }

    func updateNSView(_ recordView: RecordView, context: Context) {
        context.coordinator.onChange = onChange
        if recordView.keyCombo != keyCombo {
            recordView.keyCombo = keyCombo
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    final class Coordinator: NSObject, RecordViewDelegate {

        var onChange: (KeyCombo?) -> Void

        init(onChange: @escaping (KeyCombo?) -> Void) {
            self.onChange = onChange
        }

        func recordViewShouldBeginRecording(_ recordView: RecordView) -> Bool {
            return true
        }

        func recordView(_ recordView: RecordView, canRecordKeyCombo keyCombo: KeyCombo) -> Bool {
            return true
        }

        func recordView(_ recordView: RecordView, didChangeKeyCombo keyCombo: KeyCombo?) {
            onChange(keyCombo)
        }

        func recordViewDidEndRecording(_ recordView: RecordView) {}
    }
}
