//
//  CPYBetaPreferenceViewController.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/06/28.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa

final class CPYBetaPreferenceViewController: NSViewController {
    @IBOutlet private weak var versionTF: NSTextField!

    override func loadView() {
        super.loadView()

        versionTF.stringValue = Bundle.main.appVersion.map { str in
            return "Version: \(str)"
        } ?? ""
    }
}
