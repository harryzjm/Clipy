// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  internal enum Alert {
    internal enum Accessibility {
      /// To do this action please allow Accessibility in Security & Privacy preferences, located in System Preferences.
      internal static let message = L10n.tr("Localizable", "alert.accessibility.message", fallback: "To do this action please allow Accessibility in Security & Privacy preferences, located in System Preferences.")
      /// Open System Preferences
      internal static let openPreferences = L10n.tr("Localizable", "alert.accessibility.openPreferences", fallback: "Open System Preferences")
      /// Alert – accessibility permission
      internal static let title = L10n.tr("Localizable", "alert.accessibility.title", fallback: "Please allow Accessibility.")
    }
    internal enum ClearHistory {
      /// Alert – clear clipboard history
      internal static let message = L10n.tr("Localizable", "alert.clearHistory.message", fallback: "Are you sure you want to clear your clipboard history?")
    }
    internal enum DeleteSnippet {
      /// Alert – delete snippet / folder
      internal static let message = L10n.tr("Localizable", "alert.deleteSnippet.message", fallback: "Are you sure want to delete this item?")
    }
    internal enum LoginItem {
      /// Don't Launch
      internal static let dontLaunch = L10n.tr("Localizable", "alert.loginItem.dontLaunch", fallback: "Don't Launch")
      /// Launch on system startup
      internal static let launch = L10n.tr("Localizable", "alert.loginItem.launch", fallback: "Launch on system startup")
      /// You can change this setting in the Preferences if you want.
      internal static let message = L10n.tr("Localizable", "alert.loginItem.message", fallback: "You can change this setting in the Preferences if you want.")
      /// Alert – add to login items
      internal static let title = L10n.tr("Localizable", "alert.loginItem.title", fallback: "Launch Clipy on system startup?")
    }
  }
  internal enum Common {
    /// Shared across multiple screens
    internal static let cancel = L10n.tr("Localizable", "common.cancel", fallback: "Cancel")
    /// Clear History
    internal static let clearHistory = L10n.tr("Localizable", "common.clearHistory", fallback: "Clear History")
    /// Delete Item
    internal static let deleteItem = L10n.tr("Localizable", "common.deleteItem", fallback: "Delete Item")
    /// Menu
    internal static let menu = L10n.tr("Localizable", "common.menu", fallback: "Menu")
  }
  internal enum ExcludedApps {
    /// Preferences – Excluded Apps pane
    internal static let addButton = L10n.tr("Localizable", "excludedApps.addButton", fallback: "Add")
  }
  internal enum Menu {
    /// History
    internal static let historyTitle = L10n.tr("Localizable", "menu.historyTitle", fallback: "History")
    /// Status bar menu
    internal static let preferences = L10n.tr("Localizable", "menu.preferences", fallback: "Preferences...")
    /// Quit
    internal static let quit = L10n.tr("Localizable", "menu.quit", fallback: "Quit")
    /// Restart
    internal static let restart = L10n.tr("Localizable", "menu.restart", fallback: "Restart")
    /// Snippet
    internal static let snippetHeader = L10n.tr("Localizable", "menu.snippetHeader", fallback: "Snippet")
    /// Snippets...
    internal static let snippets = L10n.tr("Localizable", "menu.snippets", fallback: "Snippets...")
  }
  internal enum Preferences {
    /// Beta
    internal static let beta = L10n.tr("Localizable", "preferences.beta", fallback: "Beta")
    /// Excluded Apps
    internal static let excluded = L10n.tr("Localizable", "preferences.excluded", fallback: "Excluded Apps")
    /// Preferences window – pane titles
    internal static let general = L10n.tr("Localizable", "preferences.general", fallback: "General")
    /// Shortcuts
    internal static let shortcuts = L10n.tr("Localizable", "preferences.shortcuts", fallback: "Shortcuts")
    /// Type
    internal static let type = L10n.tr("Localizable", "preferences.type", fallback: "Type")
  }
  internal enum Snippets {
    /// Snippets editor
    internal static let emptyContentPlaceholder = L10n.tr("Localizable", "snippets.emptyContentPlaceholder", fallback: "Please fill in the contents of the snippet")
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
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
