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
    internal enum DatabaseReset {
      /// The database file is damaged, so nothing in it can be read. Clipy cannot save or paste anything until it is deleted and started over. The clipboard history and snippets it holds are unreadable either way.
      internal static let corrupted = L10n.tr("Localizable", "alert.databaseReset.corrupted", fallback: "The database file is damaged, so nothing in it can be read. Clipy cannot save or paste anything until it is deleted and started over. The clipboard history and snippets it holds are unreadable either way.")
      /// Delete and Start Over
      internal static let delete = L10n.tr("Localizable", "alert.databaseReset.delete", fallback: "Delete and Start Over")
      /// Keep the File
      internal static let keep = L10n.tr("Localizable", "alert.databaseReset.keep", fallback: "Keep the File")
      /// The database is encrypted with a key this Mac's keychain no longer hands out, so nothing in it can be read. Clipy cannot save or paste anything until it is deleted and started over. The clipboard history and snippets it holds are unreadable either way.
      internal static let keyMismatch = L10n.tr("Localizable", "alert.databaseReset.keyMismatch", fallback: "The database is encrypted with a key this Mac's keychain no longer hands out, so nothing in it can be read. Clipy cannot save or paste anything until it is deleted and started over. The clipboard history and snippets it holds are unreadable either way.")
      /// Alert – unreadable database
      internal static let title = L10n.tr("Localizable", "alert.databaseReset.title", fallback: "Clipy can't open its database.")
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
    internal enum Beta {
      internal enum ActionLabel {
        /// Delete from history
        internal static let deleteHistory = L10n.tr("Localizable", "preferences.beta.actionLabel.deleteHistory", fallback: "Delete from history")
        /// Paste and delete from history
        internal static let pasteAndDelete = L10n.tr("Localizable", "preferences.beta.actionLabel.pasteAndDelete", fallback: "Paste and delete from history")
        /// Paste as PlainText
        internal static let pastePlainText = L10n.tr("Localizable", "preferences.beta.actionLabel.pastePlainText", fallback: "Paste as PlainText")
      }
      internal enum Description {
        /// Beta settings might be moved to a different pane in future versions.
        internal static let betaSettings = L10n.tr("Localizable", "preferences.beta.description.betaSettings", fallback: "Beta settings might be moved to a different pane in future versions.")
      }
      internal enum Label {
        /// Version
        internal static let version = L10n.tr("Localizable", "preferences.beta.label.version", fallback: "Version")
      }
      internal enum ModifierKey {
        /// Alt
        internal static let alt = L10n.tr("Localizable", "preferences.beta.modifierKey.alt", fallback: "Alt")
        /// Command
        internal static let command = L10n.tr("Localizable", "preferences.beta.modifierKey.command", fallback: "Command")
        /// Control
        internal static let control = L10n.tr("Localizable", "preferences.beta.modifierKey.control", fallback: "Control")
        /// Shift
        internal static let shift = L10n.tr("Localizable", "preferences.beta.modifierKey.shift", fallback: "Shift")
      }
      internal enum SectionHeader {
        /// Preferences – Beta pane
        internal static let action = L10n.tr("Localizable", "preferences.beta.sectionHeader.action", fallback: "Action")
        /// Screenshot
        internal static let screenshot = L10n.tr("Localizable", "preferences.beta.sectionHeader.screenshot", fallback: "Screenshot")
      }
      internal enum ToggleLabel {
        /// Save screenshots in history
        internal static let saveScreenshots = L10n.tr("Localizable", "preferences.beta.toggleLabel.saveScreenshots", fallback: "Save screenshots in history")
      }
    }
    internal enum ClipboardType {
      /// Plain Text
      internal static let plainText = L10n.tr("Localizable", "preferences.clipboardType.plainText", fallback: "Plain Text")
      /// PNG Image
      internal static let png = L10n.tr("Localizable", "preferences.clipboardType.png", fallback: "PNG Image")
      /// Rich Text Format (RTF)
      internal static let richText = L10n.tr("Localizable", "preferences.clipboardType.richText", fallback: "Rich Text Format (RTF)")
      /// Rich Text Format Directory (RTFD)
      internal static let richTextDir = L10n.tr("Localizable", "preferences.clipboardType.richTextDir", fallback: "Rich Text Format Directory (RTFD)")
      /// TIFF Image
      internal static let tiff = L10n.tr("Localizable", "preferences.clipboardType.tiff", fallback: "TIFF Image")
    }
    internal enum ExcludedApps {
      internal enum ButtonLabel {
        /// Remove
        internal static let remove = L10n.tr("Localizable", "preferences.excludedApps.buttonLabel.remove", fallback: "Remove")
      }
      internal enum Label {
        /// Preferences – Excluded Apps pane
        internal static let header = L10n.tr("Localizable", "preferences.excludedApps.label.header", fallback: "Exclude these applications:")
      }
    }
    internal enum General {
      internal enum PickerLabel {
        /// Status Bar icon style:
        internal static let statusBarIconStyle = L10n.tr("Localizable", "preferences.general.pickerLabel.statusBarIconStyle", fallback: "Status Bar icon style:")
      }
      internal enum SectionHeader {
        /// Appearance
        internal static let appearance = L10n.tr("Localizable", "preferences.general.sectionHeader.appearance", fallback: "Appearance")
        /// Preferences – General pane
        internal static let behavior = L10n.tr("Localizable", "preferences.general.sectionHeader.behavior", fallback: "Behavior")
        /// Clipboard History
        internal static let clipboardHistory = L10n.tr("Localizable", "preferences.general.sectionHeader.clipboardHistory", fallback: "Clipboard History")
      }
      internal enum StatusType {
        /// Black
        internal static let black = L10n.tr("Localizable", "preferences.general.statusType.black", fallback: "Black")
        /// White
        internal static let white = L10n.tr("Localizable", "preferences.general.statusType.white", fallback: "White")
      }
      internal enum ToggleLabel {
        /// Input "⌘ + V" after menu item selection
        internal static let inputPasteCommand = L10n.tr("Localizable", "preferences.general.toggleLabel.inputPasteCommand", fallback: "Input \"⌘ + V\" after menu item selection")
        /// Launch on Login
        internal static let launchOnLogin = L10n.tr("Localizable", "preferences.general.toggleLabel.launchOnLogin", fallback: "Launch on Login")
      }
      internal enum Unit {
        /// days
        internal static let days = L10n.tr("Localizable", "preferences.general.unit.days", fallback: "days")
        /// items
        internal static let items = L10n.tr("Localizable", "preferences.general.unit.items", fallback: "items")
        /// px
        internal static let px = L10n.tr("Localizable", "preferences.general.unit.px", fallback: "px")
      }
      internal enum UnitLabel {
        /// Keep clipboard history for:
        internal static let keepFor = L10n.tr("Localizable", "preferences.general.unitLabel.keepFor", fallback: "Keep clipboard history for:")
        /// Max display clipboard size:
        internal static let maxDisplaySize = L10n.tr("Localizable", "preferences.general.unitLabel.maxDisplaySize", fallback: "Max display clipboard size:")
        /// Max width of menu item:
        internal static let maxWidth = L10n.tr("Localizable", "preferences.general.unitLabel.maxWidth", fallback: "Max width of menu item:")
        /// The menu font size
        internal static let menuFontSize = L10n.tr("Localizable", "preferences.general.unitLabel.menuFontSize", fallback: "The menu font size")
      }
    }
    internal enum Menu {
      internal enum PickerLabel {
        /// Match mode:
        internal static let matchMode = L10n.tr("Localizable", "preferences.menu.pickerLabel.matchMode", fallback: "Match mode:")
      }
      internal enum SectionHeader {
        /// Filter
        internal static let filter = L10n.tr("Localizable", "preferences.menu.sectionHeader.filter", fallback: "Filter")
        /// Preferences – Menu pane
        internal static let layout = L10n.tr("Localizable", "preferences.menu.sectionHeader.layout", fallback: "Layout")
        /// Menu Items
        internal static let menuItems = L10n.tr("Localizable", "preferences.menu.sectionHeader.menuItems", fallback: "Menu Items")
        /// Tool Tip
        internal static let toolTip = L10n.tr("Localizable", "preferences.menu.sectionHeader.toolTip", fallback: "Tool Tip")
      }
      internal enum ToggleLabel {
        /// Add key equivalents to numeric keys
        internal static let addNumericKeys = L10n.tr("Localizable", "preferences.menu.toggleLabel.addNumericKeys", fallback: "Add key equivalents to numeric keys")
        /// Mark menu items with numbers
        internal static let markWithNumbers = L10n.tr("Localizable", "preferences.menu.toggleLabel.markWithNumbers", fallback: "Mark menu items with numbers")
        /// Show alert panel before clear history
        internal static let showAlertBeforeClear = L10n.tr("Localizable", "preferences.menu.toggleLabel.showAlertBeforeClear", fallback: "Show alert panel before clear history")
        /// Display icons in menu items
        internal static let showIcon = L10n.tr("Localizable", "preferences.menu.toggleLabel.showIcon", fallback: "Display icons in menu items")
        /// Show tool tip on a menu item
        internal static let showToolTip = L10n.tr("Localizable", "preferences.menu.toggleLabel.showToolTip", fallback: "Show tool tip on a menu item")
      }
      internal enum Unit {
        /// chars
        internal static let chars = L10n.tr("Localizable", "preferences.menu.unit.chars", fallback: "chars")
        /// pixel
        internal static let pixel = L10n.tr("Localizable", "preferences.menu.unit.pixel", fallback: "pixel")
      }
      internal enum UnitLabel {
        /// Number of items place inside a folder:
        internal static let folderItems = L10n.tr("Localizable", "preferences.menu.unitLabel.folderItems", fallback: "Number of items place inside a folder:")
        /// Number of items place inline:
        internal static let inlineItems = L10n.tr("Localizable", "preferences.menu.unitLabel.inlineItems", fallback: "Number of items place inline:")
        /// Max length of tool tip string:
        internal static let tooltipLength = L10n.tr("Localizable", "preferences.menu.unitLabel.tooltipLength", fallback: "Max length of tool tip string:")
      }
    }
    internal enum Shortcuts {
      internal enum RecorderLabel {
        /// Preferences – Shortcuts pane
        internal static let history = L10n.tr("Localizable", "preferences.shortcuts.recorderLabel.history", fallback: "History:")
        /// Restart:
        internal static let restart = L10n.tr("Localizable", "preferences.shortcuts.recorderLabel.restart", fallback: "Restart:")
        /// Snippets:
        internal static let snippets = L10n.tr("Localizable", "preferences.shortcuts.recorderLabel.snippets", fallback: "Snippets:")
      }
    }
    internal enum TypePane {
      internal enum SectionHeader {
        /// Preferences – Type pane
        internal static let storeTypes = L10n.tr("Localizable", "preferences.typePane.sectionHeader.storeTypes", fallback: "Store the following clipboard types")
      }
    }
  }
  internal enum Snippets {
    /// Snippets – editor content
    internal static let emptyContentPlaceholder = L10n.tr("Localizable", "snippets.emptyContentPlaceholder", fallback: "Please fill in the contents of the snippet")
    internal enum Detail {
      internal enum Folder {
        /// Shortcut
        internal static let shortcutLabel = L10n.tr("Localizable", "snippets.detail.folder.shortcutLabel", fallback: "Shortcut")
        /// Folder
        internal static let title = L10n.tr("Localizable", "snippets.detail.folder.title", fallback: "Folder")
        /// Title
        internal static let titleLabel = L10n.tr("Localizable", "snippets.detail.folder.titleLabel", fallback: "Title")
      }
      internal enum NoSelection {
        /// Select a folder or a snippet to edit.
        internal static let description = L10n.tr("Localizable", "snippets.detail.noSelection.description", fallback: "Select a folder or a snippet to edit.")
        /// Snippets – detail view
        internal static let title = L10n.tr("Localizable", "snippets.detail.noSelection.title", fallback: "No Selection")
      }
    }
    internal enum Editor {
      /// Snippets – editor toolbar
      internal static let title = L10n.tr("Localizable", "snippets.editor.title", fallback: "Snippet Editor")
      internal enum Toolbar {
        /// Add Folder
        internal static let addFolder = L10n.tr("Localizable", "snippets.editor.toolbar.addFolder", fallback: "Add Folder")
        /// Add Snippet
        internal static let addSnippet = L10n.tr("Localizable", "snippets.editor.toolbar.addSnippet", fallback: "Add Snippet")
        /// Enable/Disable
        internal static let enableDisable = L10n.tr("Localizable", "snippets.editor.toolbar.enableDisable", fallback: "Enable/Disable")
        /// Export
        internal static let export = L10n.tr("Localizable", "snippets.editor.toolbar.export", fallback: "Export")
        /// Import
        internal static let `import` = L10n.tr("Localizable", "snippets.editor.toolbar.import", fallback: "Import")
      }
    }
    internal enum Sidebar {
      internal enum ContextMenu {
        /// Delete
        internal static let delete = L10n.tr("Localizable", "snippets.sidebar.contextMenu.delete", fallback: "Delete")
        /// Disable
        internal static let disable = L10n.tr("Localizable", "snippets.sidebar.contextMenu.disable", fallback: "Disable")
        /// Enable
        internal static let enable = L10n.tr("Localizable", "snippets.sidebar.contextMenu.enable", fallback: "Enable")
        /// Move to Folder
        internal static let moveToFolder = L10n.tr("Localizable", "snippets.sidebar.contextMenu.moveToFolder", fallback: "Move to Folder")
        /// Snippets – sidebar context menu
        internal static let rename = L10n.tr("Localizable", "snippets.sidebar.contextMenu.rename", fallback: "Rename")
      }
    }
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
