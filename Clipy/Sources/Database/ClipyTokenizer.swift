//
//  ClipyTokenizer.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation
import WCDBSwift

/// The one fts5 tokenizer `clip_fts` is built with: words, digits, and Chinese characters both
/// as written and by pinyin.
///
/// - A run of ASCII letters, or of ASCII digits, is one token, lowercased. Letters and digits
///   are separate runs (`abc123` is `abc` then `123`).
/// - In a document, a letter run in camelCase takes one position per part, so a search can
///   start at any of them: each position holds the rest of the run from that part on, with the
///   part itself colocated (`getUserName` → `getusername | get`, `username | user`, `name`).
///   A part starts at a capital after a lower-case letter, or at the last capital of a run of
///   them that a lower-case letter follows (`HTTP|Server`). A run of more than
///   `maxCamelParts` parts is mixed-case noise — a key, a token — and stays whole.
/// - A character in `PinyinDictionary` is one token, and in a document every reading and its
///   initial are stacked on it as colocated tokens (`重` → `重 | zhong z chong c tong t`).
/// - Any other letter or number (kana, `é`) is a token of its own, lowercased.
/// - Everything else — whitespace, punctuation, emoji — separates tokens and is dropped.
///
/// So `Complete 中国` indexes as `complete`, `中 | zhong z`, `国 | guo g`: one position each. The
/// query side never expands a character: typed pinyin arrives as plain letter runs, already split
/// into per-character tokens by `PinyinQuery`, and meets the readings in the index. Nor does it
/// split camelCase — `UserName*` is one token, and the rest-of-run token `username` is what it
/// meets. There is no stemming — search-as-you-type matches by prefix, and a stem would cut off
/// the word the user is still typing.
///
/// `highlight()` skips colocated tokens, so a hit is marked over the position's own token: a
/// camelCase part is marked from where it starts to the end of the run, the way a word hit is
/// marked on the whole word.
///
/// A token must stay valid until the next call, so every one is copied into `buffer`, which this
/// instance owns.
final class ClipyTokenizer: Tokenizer {

    /// The name `clip_fts` names in `tokenize = …`. Persisted in the table's schema.
    static let name = "clipy"

    /// Registers the tokenizer with WCDB, once per process. Touch it before any handle adds it.
    ///
    /// Also starts loading the pinyin dictionary: it takes long enough to notice, and the first
    /// thing to need it is often a keystroke in the history filter, since `highlight()`
    /// re-tokenizes every hit.
    static let registered: Void = {
        Database.register(tokenizer: ClipyTokenizer.self, of: name, of: .FTS5)
        PinyinDictionary.warmUp()
    }()

    /// `FTS5_TOKENIZE_QUERY` in fts5.h: the input is a MATCH expression's phrase, not a document.
    private static let tokenizeQuery = 0x0001
    /// `FTS5_TOKEN_COLOCATED` in fts5.h: the token shares the previous token's position.
    private static let tokenColocated: Int32 = 0x0001
    /// More parts than this and a letter run is not split. Real identifiers rarely pass 6–8, and
    /// the rest-of-run tokens grow with the square of the part count.
    static let maxCamelParts = 12

    private var input: UnsafePointer<UInt8>?
    private var length = 0
    private var isQuery = false
    private var cursor = 0

    /// Readings still to hand out for the character just emitted, all at its position.
    private var colocated: [[UInt8]] = []
    private var colocatedIndex = 0
    /// Where each camelCase part of the letter run just scanned starts. Every part's token runs
    /// to the end of that run, which is `cursor` until the last part is out.
    private var camelStarts: [Int] = []
    private var camelIndex = 0
    private var tokenStart: Int32 = 0
    private var tokenEnd: Int32 = 0

    private var buffer: UnsafeMutablePointer<UInt8>
    private var capacity = 64
    private var tokenLength = 0

    init(args: [String]) {
        buffer = .allocate(capacity: capacity)
    }

    deinit {
        buffer.deallocate()
    }

    func load(input: UnsafePointer<Int8>?, length: Int, flags: Int) {
        self.input = input.map { UnsafeRawPointer($0).assumingMemoryBound(to: UInt8.self) }
        self.length = input == nil ? 0 : length
        isQuery = flags & Self.tokenizeQuery != 0
        cursor = 0
        colocated = []
        colocatedIndex = 0
        camelStarts = []
        camelIndex = 0
    }

    func nextToken(ppToken: UnsafeMutablePointer<UnsafePointer<Int8>?>,
                   pnBytes: UnsafeMutablePointer<Int32>,
                   piStart: UnsafeMutablePointer<Int32>,
                   piEnd: UnsafeMutablePointer<Int32>,
                   pFlags: UnsafeMutablePointer<Int32>?,
                   piPosition: UnsafeMutablePointer<Int32>?) -> TokenizerErrorCode {
        if colocatedIndex < colocated.count {
            let reading = colocated[colocatedIndex]
            colocatedIndex += 1
            reading.withUnsafeBufferPointer { store($0, lowercased: false) }
            return emit(ppToken, pnBytes, piStart, piEnd, pFlags, flags: Self.tokenColocated)
        }
        guard let input else { return .Done }
        if camelIndex < camelStarts.count {
            return emitCamelPart(of: input, ppToken, pnBytes, piStart, piEnd, pFlags)
        }

        while cursor < length {
            let start = cursor
            let lead = input[cursor]

            if lead < 0x80 {
                guard let isDigit = Self.wordClass(of: lead) else {
                    cursor += 1
                    continue
                }
                cursor += 1
                while cursor < length, Self.wordClass(of: input[cursor]) == isDigit {
                    cursor += 1
                }
                if !isDigit && !isQuery {
                    let starts = Self.camelStarts(in: input + start, count: cursor - start)
                    if starts.count > 1 {
                        camelStarts = starts.map { start + $0 }
                        camelIndex = 0
                        return emitCamelPart(of: input, ppToken, pnBytes, piStart, piEnd, pFlags)
                    }
                }
                store(UnsafeBufferPointer(start: input + start, count: cursor - start), lowercased: true)
                return emit(ppToken, pnBytes, piStart, piEnd, pFlags, from: start)
            }

            guard let (scalar, width) = Self.decodeScalar(input + cursor, available: length - cursor) else {
                cursor += 1
                continue
            }
            cursor += width

            if let readings = PinyinDictionary.readings[scalar.value] {
                store(UnsafeBufferPointer(start: input + start, count: width), lowercased: false)
                if !isQuery {
                    colocated = readings
                    colocatedIndex = 0
                }
                return emit(ppToken, pnBytes, piStart, piEnd, pFlags, from: start)
            }
            if scalar.properties.isAlphabetic || scalar.properties.numericType != nil {
                let folded = Array(String(Character(scalar)).lowercased().utf8)
                folded.withUnsafeBufferPointer { store($0, lowercased: false) }
                return emit(ppToken, pnBytes, piStart, piEnd, pFlags, from: start)
            }
        }
        return .Done
    }
}

// MARK: - Output
private extension ClipyTokenizer {

    /// Copies `bytes` into `buffer`, folding ASCII case when asked.
    func store(_ bytes: UnsafeBufferPointer<UInt8>, lowercased: Bool) {
        if bytes.count > capacity {
            buffer.deallocate()
            capacity = bytes.count * 2
            buffer = .allocate(capacity: capacity)
        }
        for (offset, byte) in bytes.enumerated() {
            buffer[offset] = lowercased ? Self.asciiLowercased(byte) : byte
        }
        tokenLength = bytes.count
    }

    /// The camelCase part at `camelIndex`, as the rest of the run from its start, with the part
    /// alone queued as colocated — unless it is the last part, which already is the rest.
    func emitCamelPart(of input: UnsafePointer<UInt8>,
                       _ ppToken: UnsafeMutablePointer<UnsafePointer<Int8>?>,
                       _ pnBytes: UnsafeMutablePointer<Int32>,
                       _ piStart: UnsafeMutablePointer<Int32>,
                       _ piEnd: UnsafeMutablePointer<Int32>,
                       _ pFlags: UnsafeMutablePointer<Int32>?) -> TokenizerErrorCode {
        let start = camelStarts[camelIndex]
        camelIndex += 1
        if camelIndex < camelStarts.count {
            let part = UnsafeBufferPointer(start: input + start, count: camelStarts[camelIndex] - start)
            colocated = [part.map(Self.asciiLowercased)]
            colocatedIndex = 0
        } else {
            camelStarts = []
            camelIndex = 0
        }
        store(UnsafeBufferPointer(start: input + start, count: cursor - start), lowercased: true)
        return emit(ppToken, pnBytes, piStart, piEnd, pFlags, from: start)
    }

    /// A token at a fresh position, spanning `start ..< cursor` of the input.
    func emit(_ ppToken: UnsafeMutablePointer<UnsafePointer<Int8>?>,
              _ pnBytes: UnsafeMutablePointer<Int32>,
              _ piStart: UnsafeMutablePointer<Int32>,
              _ piEnd: UnsafeMutablePointer<Int32>,
              _ pFlags: UnsafeMutablePointer<Int32>?,
              from start: Int) -> TokenizerErrorCode {
        tokenStart = Int32(start)
        tokenEnd = Int32(cursor)
        return emit(ppToken, pnBytes, piStart, piEnd, pFlags, flags: 0)
    }

    /// Hands out whatever `store` last put in `buffer`, over the current span.
    func emit(_ ppToken: UnsafeMutablePointer<UnsafePointer<Int8>?>,
              _ pnBytes: UnsafeMutablePointer<Int32>,
              _ piStart: UnsafeMutablePointer<Int32>,
              _ piEnd: UnsafeMutablePointer<Int32>,
              _ pFlags: UnsafeMutablePointer<Int32>?,
              flags: Int32) -> TokenizerErrorCode {
        ppToken.pointee = UnsafeRawPointer(buffer).assumingMemoryBound(to: Int8.self)
        pnBytes.pointee = Int32(tokenLength)
        piStart.pointee = tokenStart
        piEnd.pointee = tokenEnd
        pFlags?.pointee = flags
        return .OK
    }
}

// MARK: - Scanning
private extension ClipyTokenizer {

    /// `false` for an ASCII letter, `true` for a digit, `nil` for anything else — so a run can
    /// be extended while the class holds.
    static func wordClass(of byte: UInt8) -> Bool? {
        switch byte {
        case 0x30...0x39: return true
        case 0x41...0x5A, 0x61...0x7A: return false
        default: return nil
        }
    }

    static func isUppercase(_ byte: UInt8) -> Bool {
        byte >= 0x41 && byte <= 0x5A
    }

    static func asciiLowercased(_ byte: UInt8) -> UInt8 {
        isUppercase(byte) ? byte | 0x20 : byte
    }

    /// Where each camelCase part of an ASCII letter run starts, `0` first: at a capital after a
    /// lower-case letter (`get|User`), and at the last capital of a run of them that a
    /// lower-case letter follows (`HTTP|Server`). Just `[0]` — keep the run whole — when there
    /// are more than `maxCamelParts`.
    static func camelStarts(in bytes: UnsafePointer<UInt8>, count: Int) -> [Int] {
        var starts = [0]
        for index in 1..<max(count, 1) where isUppercase(bytes[index]) {
            let afterLower = !isUppercase(bytes[index - 1])
            let beforeLower = index + 1 < count && !isUppercase(bytes[index + 1])
            guard afterLower || beforeLower else { continue }
            starts.append(index)
            if starts.count > maxCamelParts { return [0] }
        }
        return starts
    }

    /// Decodes one multi-byte UTF-8 sequence. `nil` for a malformed or truncated one, which the
    /// caller steps over a byte at a time.
    static func decodeScalar(_ bytes: UnsafePointer<UInt8>, available: Int) -> (Unicode.Scalar, Int)? {
        let lead = bytes[0]
        let width: Int
        var value: UInt32
        switch lead {
        case 0xC2...0xDF: width = 2; value = UInt32(lead & 0x1F)
        case 0xE0...0xEF: width = 3; value = UInt32(lead & 0x0F)
        case 0xF0...0xF4: width = 4; value = UInt32(lead & 0x07)
        default: return nil
        }
        guard width <= available else { return nil }
        for index in 1..<width {
            let byte = bytes[index]
            guard byte & 0xC0 == 0x80 else { return nil }
            value = value << 6 | UInt32(byte & 0x3F)
        }
        return Unicode.Scalar(value).map { ($0, width) }
    }
}
