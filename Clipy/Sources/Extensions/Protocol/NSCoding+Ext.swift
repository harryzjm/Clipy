//
//  NSCoding+Ext.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/11/19.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

extension Data {
    func unarchive() -> Any? {
        do {
            return try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(self)
        } catch {
            lError(error)
            return nil
        }
    }
}

extension NSCoding {
    func archive() -> Data? {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
        } catch {
            lError(error)
            return nil
        }
    }

    func archive(toFilePath filePath: String) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
            try data.write(to: .init(fileURLWithPath: filePath))
        } catch { lError(error) }
    }
}

extension Array where Element: NSCoding {
    func archive() -> Data? {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
        } catch {
            lError(error)
            return nil
        }
    }
}

extension UserDefaults {
    func setArchiveObject<T: NSCoding>(_ object: T, forKey key: String) {
        if let data = object.archive() {
            set(data, forKey: key)
        }
    }

    func archiveObject<T: NSCoding>(forKey key: String, with type: T.Type) -> T? {
        guard
            let data = object(forKey: key) as? Data,
            let object = data.unarchive() as? T
        else { return nil }
        return object
    }
}
