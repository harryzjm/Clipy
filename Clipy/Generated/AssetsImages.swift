// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
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
  internal enum SnippetEditor {
    internal static let snippetsAddFolder = ImageAsset(name: "SnippetEditor/snippets_add_folder")
    internal static let snippetsAddFolderOn = ImageAsset(name: "SnippetEditor/snippets_add_folder_on")
    internal static let snippetsAddSnippet = ImageAsset(name: "SnippetEditor/snippets_add_snippet")
    internal static let snippetsAddSnippetOn = ImageAsset(name: "SnippetEditor/snippets_add_snippet_on")
    internal static let snippetsDeleteSnippet = ImageAsset(name: "SnippetEditor/snippets_delete_snippet")
    internal static let snippetsDeleteSnippetOn = ImageAsset(name: "SnippetEditor/snippets_delete_snippet_on")
    internal static let snippetsEnableSnippet = ImageAsset(name: "SnippetEditor/snippets_enable_snippet")
    internal static let snippetsEnableSnippetOn = ImageAsset(name: "SnippetEditor/snippets_enable_snippet_on")
    internal static let snippetsExport = ImageAsset(name: "SnippetEditor/snippets_export")
    internal static let snippetsExportOn = ImageAsset(name: "SnippetEditor/snippets_export_on")
    internal static let snippetsIconFolderBlue = ImageAsset(name: "SnippetEditor/snippets_icon_folder_blue")
    internal static let snippetsIconFolderWhite = ImageAsset(name: "SnippetEditor/snippets_icon_folder_white")
    internal static let snippetsImport = ImageAsset(name: "SnippetEditor/snippets_import")
    internal static let snippetsImportOn = ImageAsset(name: "SnippetEditor/snippets_import_on")
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

internal struct ImageAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Image = UIImage
  #endif

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
}

internal extension ImageAsset.Image {
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
