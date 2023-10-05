// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

// Deprecated typealiases
@available(*, deprecated, renamed: "ColorAsset.Color", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetColorTypeAlias = ColorAsset.Color
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
internal enum Asset {
  internal enum Color {
    internal static let clipy = ColorAsset(name: "Color/clipy")
    internal static let tabTitle = ColorAsset(name: "Color/tabTitle")
    internal static let title = ColorAsset(name: "Color/title")
  }
  internal enum Common {
    internal static let iconFolder = ImageAsset(name: "Common/icon_folder")
    internal static let iconText = ImageAsset(name: "Common/icon_text")
  }
  internal enum FileIcon {
    internal static let apk = ImageAsset(name: "FileIcon/apk")
    internal static let code = ImageAsset(name: "FileIcon/code")
    internal static let dmg = ImageAsset(name: "FileIcon/dmg")
    internal static let doc = ImageAsset(name: "FileIcon/doc")
    internal static let folder = ImageAsset(name: "FileIcon/folder")
    internal static let image = ImageAsset(name: "FileIcon/image")
    internal static let music = ImageAsset(name: "FileIcon/music")
    internal static let pdf = ImageAsset(name: "FileIcon/pdf")
    internal static let ppt = ImageAsset(name: "FileIcon/ppt")
    internal static let txt = ImageAsset(name: "FileIcon/txt")
    internal static let unknow = ImageAsset(name: "FileIcon/unknow")
    internal static let video = ImageAsset(name: "FileIcon/video")
    internal static let xls = ImageAsset(name: "FileIcon/xls")
    internal static let zip = ImageAsset(name: "FileIcon/zip")
  }
  internal enum Preference {
    internal static let beta = ImageAsset(name: "Preference/beta")
    internal static let betaOn = ImageAsset(name: "Preference/beta_on")
    internal static let excluded = ImageAsset(name: "Preference/excluded")
    internal static let excludedOn = ImageAsset(name: "Preference/excluded_on")
    internal static let general = ImageAsset(name: "Preference/general")
    internal static let generalOn = ImageAsset(name: "Preference/general_on")
    internal static let menu = ImageAsset(name: "Preference/menu")
    internal static let menuOn = ImageAsset(name: "Preference/menu_on")
    internal static let shortcut = ImageAsset(name: "Preference/shortcut")
    internal static let shortcutOn = ImageAsset(name: "Preference/shortcut_on")
    internal static let type = ImageAsset(name: "Preference/type")
    internal static let typeOn = ImageAsset(name: "Preference/type_on")
    internal static let update = ImageAsset(name: "Preference/update")
    internal static let updateOn = ImageAsset(name: "Preference/update_on")
  }
  internal enum Snippet {
    internal static let addFolder = ImageAsset(name: "Snippet/add_folder")
    internal static let addFolderOn = ImageAsset(name: "Snippet/add_folder_on")
    internal static let addSnippet = ImageAsset(name: "Snippet/add_snippet")
    internal static let addSnippetOn = ImageAsset(name: "Snippet/add_snippet_on")
    internal static let deleteSnippet = ImageAsset(name: "Snippet/delete_snippet")
    internal static let deleteSnippetOn = ImageAsset(name: "Snippet/delete_snippet_on")
    internal static let enableSnippet = ImageAsset(name: "Snippet/enable_snippet")
    internal static let enableSnippetOn = ImageAsset(name: "Snippet/enable_snippet_on")
    internal static let export = ImageAsset(name: "Snippet/export")
    internal static let exportOn = ImageAsset(name: "Snippet/export_on")
    internal static let iconFolderBlue = ImageAsset(name: "Snippet/icon_folder_blue")
    internal static let iconFolderWhite = ImageAsset(name: "Snippet/icon_folder_white")
    internal static let `import` = ImageAsset(name: "Snippet/import")
    internal static let importOn = ImageAsset(name: "Snippet/import_on")
  }
  internal enum StatusIcon {
    internal static let menuBlack = ImageAsset(name: "StatusIcon/menu_black")
    internal static let menuWhite = ImageAsset(name: "StatusIcon/menu_white")
  }
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

internal final class ColorAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Color = NSColor
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Color = UIColor
  #endif

  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  internal private(set) lazy var color: Color = {
    guard let color = Color(asset: self) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }()

  #if os(iOS) || os(tvOS)
  @available(iOS 11.0, tvOS 11.0, *)
  internal func color(compatibleWith traitCollection: UITraitCollection) -> Color {
    let bundle = BundleToken.bundle
    guard let color = Color(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal private(set) lazy var swiftUIColor: SwiftUI.Color = {
    SwiftUI.Color(asset: self)
  }()
  #endif

  fileprivate init(name: String) {
    self.name = name
  }
}

internal extension ColorAsset.Color {
  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  convenience init?(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSColor.Name(asset.name), bundle: bundle)
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Color {
  init(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }
}
#endif

internal struct ImageAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Image = UIImage
  #endif

  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, macOS 10.7, *)
  internal var image: Image {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let name = NSImage.Name(self.name)
    let image = (bundle == .main) ? NSImage(named: name) : bundle.image(forResource: name)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }

  #if os(iOS) || os(tvOS)
  @available(iOS 8.0, tvOS 9.0, *)
  internal func image(compatibleWith traitCollection: UITraitCollection) -> Image {
    let bundle = BundleToken.bundle
    guard let result = Image(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

internal extension ImageAsset.Image {
  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, *)
  @available(macOS, deprecated,
    message: "This initializer is unsafe on macOS, please use the ImageAsset.image property")
  convenience init?(asset: ImageAsset) {
    #if os(iOS) || os(tvOS)
    let bundle = BundleToken.bundle
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSImage.Name(asset.name))
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Image {
  init(asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }

  init(asset: ImageAsset, label: Text) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
