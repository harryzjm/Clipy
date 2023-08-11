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
    internal static let prefBeta = ImageAsset(name: "Preference/pref_beta")
    internal static let prefBetaOn = ImageAsset(name: "Preference/pref_beta_on")
    internal static let prefExcluded = ImageAsset(name: "Preference/pref_excluded")
    internal static let prefExcludedOn = ImageAsset(name: "Preference/pref_excluded_on")
    internal static let prefGeneral = ImageAsset(name: "Preference/pref_general")
    internal static let prefGeneralOn = ImageAsset(name: "Preference/pref_general_on")
    internal static let prefMenu = ImageAsset(name: "Preference/pref_menu")
    internal static let prefMenuOn = ImageAsset(name: "Preference/pref_menu_on")
    internal static let prefShortcut = ImageAsset(name: "Preference/pref_shortcut")
    internal static let prefShortcutOn = ImageAsset(name: "Preference/pref_shortcut_on")
    internal static let prefType = ImageAsset(name: "Preference/pref_type")
    internal static let prefTypeOn = ImageAsset(name: "Preference/pref_type_on")
    internal static let prefUpdate = ImageAsset(name: "Preference/pref_update")
    internal static let prefUpdateOn = ImageAsset(name: "Preference/pref_update_on")
  }
  internal enum StatusIcon {
    internal static let statusbarMenuBlack = ImageAsset(name: "StatusIcon/statusbar_menu_black")
    internal static let statusbarMenuWhite = ImageAsset(name: "StatusIcon/statusbar_menu_white")
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
