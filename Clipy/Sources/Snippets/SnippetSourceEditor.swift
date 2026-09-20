//
//  SnippetSourceEditor.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//

import SwiftUI
import CodeEditLanguages
import CodeEditSourceEditor

/// The snippet body editor, and the only file in the app that names a `CodeEdit*` type.
///
/// Everything outside talks in `TreeSitterLanguage` raw values (`"swift"`, `"plainText"`, …),
/// which is what `CPYSnippet.language` stores — so the model and database layers never see the
/// package, and `ClipyTests`, which does not link it, keeps compiling.
struct SnippetSourceEditor: View {

    @Binding var text: String
    /// A `TreeSitterLanguage` raw value. Anything unrecognised falls back to plain text.
    let languageIdentifier: String
    /// Drawn over the first line while `text` is empty. `CPYPlaceHolderTextView` used to paint
    /// this in `draw(_:)`; the editor has no placeholder of its own, so it stays an overlay.
    let placeholder: String

    @AppStorage(Preferences.Snippets.editorShowGutter)
    private var showGutter = true
    @AppStorage(Preferences.Snippets.editorWrapLines)
    private var wrapLines = true
    @AppStorage(Preferences.Snippets.editorShowMinimap)
    private var showMinimap = true

    /// Cursor, scroll offset and find-bar state. Owned here and never persisted: a snippet is
    /// short enough that restoring a caret position would be noise.
    @State private var editorState = SourceEditorState()

    // Spelled out: the app has its own `Environment` (the service locator), which shadows
    // SwiftUI's property wrapper — the same reason `SwiftUI.Color` is qualified everywhere here.
    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SourceEditor(
            $text,
            language: CodeLanguage.clipy(identifier: languageIdentifier),
            configuration: SourceEditorConfiguration(
                appearance: .init(theme: colorScheme == .dark ? .clipyDark : .clipyLight,
                                  font: Self.font,
                                  wrapLines: wrapLines),
                behavior: .init(indentOption: .spaces(count: 4)),
                peripherals: .init(showGutter: showGutter,
                                   showMinimap: showMinimap,
                                   showReformattingGuide: false,
                                   showFoldingRibbon: false)
            ),
            state: $editorState
        )
        .overlay(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: Self.fontSize, design: .monospaced))
                    .foregroundStyle(SwiftUI.Color(nsColor: .placeholderTextColor))
                    .padding(.leading, textLeadingInset)
                    .padding(.top, 1)
                    .allowsHitTesting(false)
            }
        }
    }

    private static let fontSize: CGFloat = 13
    private static let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

    /// Roughly how far the gutter pushes the first glyph in. The gutter sizes itself to the
    /// widest line number, but a document empty enough to show a placeholder has exactly one
    /// line, so one constant is enough.
    private var textLeadingInset: CGFloat { showGutter ? 42 : 6 }
}

/// The language picker above the editor.
///
/// Reads and writes a raw value so the caller can hand it straight to the store.
struct SnippetLanguagePicker: View {

    @Binding var languageIdentifier: String

    var body: some View {
        Picker(L10n.Snippets.Detail.Snippet.languageLabel, selection: $languageIdentifier) {
            // `allLanguages` leaves plain text out — it is `CodeLanguage.default`, the fallback
            // for anything tree-sitter has no grammar for.
            ForEach([CodeLanguage.default] + CodeLanguage.allLanguages, id: \.id.rawValue) { language in
                Text(language.clipyDisplayName).tag(language.id.rawValue)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
    }
}

// MARK: - Language identifiers
private extension CodeLanguage {

    /// Raw value → language, falling back to plain text. Covers both a snippet that predates the
    /// field and a grammar dropped by a future `CodeEditLanguages`.
    static func clipy(identifier: String) -> CodeLanguage {
        allLanguages.first { $0.id.rawValue == identifier } ?? .default
    }

    /// `TreeSitterLanguage` raw values are Swift case names, so most of them capitalise into
    /// something presentable and the rest are listed here.
    var clipyDisplayName: String {
        switch id.rawValue {
        case "c": return "C"
        case "cpp": return "C++"
        case "cSharp": return "C#"
        case "css": return "CSS"
        case "goMod": return "Go Mod"
        case "html": return "HTML"
        case "javascript": return "JavaScript"
        case "jsdoc": return "JSDoc"
        case "json": return "JSON"
        case "jsx": return "JSX"
        case "objc": return "Objective-C"
        case "ocaml": return "OCaml"
        case "ocamlInterface": return "OCaml Interface"
        case "markdownInline": return "Markdown (Inline)"
        case "php": return "PHP"
        case "plainText": return "Plain Text"
        case "sql": return "SQL"
        case "toml": return "TOML"
        case "typescript": return "TypeScript"
        case "tsx": return "TSX"
        case "yaml": return "YAML"
        default: return id.rawValue.capitalized
        }
    }
}

// MARK: - Themes
/// Two fixed themes rather than dynamic `NSColor`s: the controller copies these colours onto
/// views and onto attributed runs, so an appearance-aware colour would be resolved once, against
/// whichever appearance happened to be current. `SnippetSourceEditor` swaps the whole theme
/// instead, which `SourceEditorConfiguration`'s `Equatable` conformance turns into a reload.
///
/// The palette is Xcode's default light/dark, by way of the package's own example app.
private extension EditorTheme {

    /// The palette below is all opaque six-digit hex, so the failable initialiser can never
    /// actually fail; `.textColor` is a fallback that exists only to keep the literals readable.
    static func themeColor(_ hex: String) -> NSColor {
        NSColor(hexString: hex) ?? .textColor
    }

    static let clipyLight = EditorTheme(
        text: Attribute(color: themeColor("000000")),
        insertionPoint: themeColor("000000"),
        invisibles: Attribute(color: themeColor("D6D6D6")),
        background: themeColor("FFFFFF"),
        lineHighlight: themeColor("ECF5FF"),
        selection: themeColor("B2D7FF"),
        keywords: Attribute(color: themeColor("9B2393"), bold: true),
        commands: Attribute(color: themeColor("326D74")),
        types: Attribute(color: themeColor("0B4F79")),
        attributes: Attribute(color: themeColor("815F03")),
        variables: Attribute(color: themeColor("0F68A0")),
        values: Attribute(color: themeColor("6C36A9")),
        numbers: Attribute(color: themeColor("1C00CF")),
        strings: Attribute(color: themeColor("C41A16")),
        characters: Attribute(color: themeColor("1C00CF")),
        comments: Attribute(color: themeColor("267507"))
    )

    static let clipyDark = EditorTheme(
        text: Attribute(color: themeColor("FFFFFF")),
        insertionPoint: themeColor("007AFF"),
        invisibles: Attribute(color: themeColor("53606E")),
        background: themeColor("292A30"),
        lineHighlight: themeColor("2F3239"),
        selection: themeColor("646F83"),
        keywords: Attribute(color: themeColor("FF7AB2"), bold: true),
        commands: Attribute(color: themeColor("78C2B3")),
        types: Attribute(color: themeColor("6BDFFF")),
        attributes: Attribute(color: themeColor("CC9768")),
        variables: Attribute(color: themeColor("4EB0CC")),
        values: Attribute(color: themeColor("B281EB")),
        numbers: Attribute(color: themeColor("D9C97C")),
        strings: Attribute(color: themeColor("FF8170")),
        characters: Attribute(color: themeColor("D9C97C")),
        comments: Attribute(color: themeColor("7F8C98"))
    )
}
