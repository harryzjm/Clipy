//
//  Realm+Migration.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/10/16.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import RealmSwift

extension Realm {
    static func migration() {
        let config = Realm.Configuration(schemaVersion: 7, migrationBlock: { migration, oldSchemaVersion in
            if oldSchemaVersion <= 5 {
                // Update RealmObjc to RealmSwift
                migration.enumerateObjects(ofType: CPYClip.className(), { oldObject, newObject in
                    newObject!["dataPath"] = oldObject!["dataPath"]
                    newObject!["title"] = oldObject!["title"]
                    newObject!["dataHash"] = oldObject!["dataHash"]
                    newObject!["primaryType"] = oldObject!["primaryType"]
                    newObject!["updateTime"] = oldObject!["updateTime"]
                    newObject!["thumbnailPath"] = oldObject!["thumbnailPath"]
                })
            }
        })
        Realm.Configuration.defaultConfiguration = config
        let realm = try! Realm()
        lDebug(realm.configuration.fileURL)
    }
}
