// 
//  CPYClipData+FileType.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
// 
//  Created by Aphro on 8/12/23.
// 
//  Copyright © 2015-2023 Clipy Project.
//

import Foundation
import Cocoa

extension CPYClipData {
    enum FileType: CaseIterable {
        case folder
        case txt
        case zip
        case pdf
        case doc
        case xls
        case ppt
        case code
        case apk
        case dmg
        case image
        case music
        case video
        case unknow

        init(_ ext: String?) {
            if let ext = ext, ext.isNotEmpty {
                let ext = ext.lowercased()
                self = FileType.allCases.lazy.first { type in
                    type.ext.contains(ext)
                } ?? .unknow
            } else {
                self = .folder
            }
        }

        var ext: [String] {
            switch self {
            case .txt:
                return ["txt", "ips", "beta", "crash", "md"]
            case .zip:
                return ["rar", "7z", "zip", "arj", "gz", "z"]
            case .pdf:
                return ["pdf"]
            case .doc:
                return ["docx", "doc", "dot", "dotx", "docm", "dotm", "wps", "wpt", "rtf", "pages"]
            case .xls:
                return ["xls", "xlt", "xlsx", "xlsm", "dbf", "xml", "xltx", "xltm", "et", "ett", "numbers", "csv"]
            case .ppt:
                return ["pptx", "ppt", "pptm", "pot", "potx", "pps", "ppsx", "potm", "ppsm", "dps", "dpt", "key"]
            case .code:
                return ["htm", "html", "mht", "mhtml", "c", "c++", "c#", "swift", "h", "m", "mm", "py", "sh", "rb", "js"]
            case .apk:
                return ["apk"]
            case .dmg:
                return ["dmg", "exe", "pkg", "ipa"]
            case .image:
                return [ "bmp", "jpg", "png", "tif", "gif", "pcx", "tga", "exif", "fpx", "svg", "psd", "cdr", "pcd", "dxf", "ufo", "eps", "ai", "raw", "wmf", "webp", "jpeg", "heic" ]
            case .music:
                return ["wav", "aif", "au", "mp3", "ram", "wma", "mmf", "amr", "aac", "flac"]
            case .video:
                return ["avi", "asf", "mov", "rmvb", "rm", "flv", "mp4", "3gp", "wmf", "mpeg", "divx"]
            case .unknow, .folder:
                return []
            }
        }

        var image: NSImage {
            switch self {
            case .folder: return Asset.FileIcon.folder.image
            case .txt: return Asset.FileIcon.txt.image
            case .zip: return Asset.FileIcon.zip.image
            case .pdf: return Asset.FileIcon.pdf.image
            case .doc: return Asset.FileIcon.doc.image
            case .xls: return Asset.FileIcon.xls.image
            case .ppt: return Asset.FileIcon.ppt.image
            case .code: return Asset.FileIcon.code.image
            case .apk: return Asset.FileIcon.apk.image
            case .dmg: return Asset.FileIcon.dmg.image
            case .image: return Asset.FileIcon.image.image
            case .music: return Asset.FileIcon.music.image
            case .video: return Asset.FileIcon.video.image
            case .unknow: return Asset.FileIcon.unknow.image
            }
        }
    }
}
