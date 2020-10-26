//
//  NSUserDefaults+ArchiveData.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/06/23.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import Cocoa

extension UserDefaults {
    func setArchiveData<T: NSCoding>(_ object: T, forKey key: String) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false)
            set(data, forKey: key)
        } catch {
            lError(error)
        }
    }

    func archiveDataForKey<T: NSCoding & NSObject>(_: T.Type, key: String) -> T? {
        guard
            let data = object(forKey: key) as? Data,
            let object = try? NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data)
        else { return nil }
        return object
    }
}
