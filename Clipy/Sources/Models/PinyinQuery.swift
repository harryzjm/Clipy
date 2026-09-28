//
//  PinyinQuery.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation

/// Splits typed pinyin into the per-character tokens WCDB's Pinyin tokenizer indexes.
///
/// The tokenizer indexes each Chinese character at its own position, with every reading and the
/// first letter of each as colocated tokens (`重` → `zhong z chong c tong t`). In query mode it
/// does nothing of the sort — it passes each run of letters through whole — so `zhongguo` has to
/// arrive already split, as the phrase `"zhong guo"`. That split is ambiguous (`xian` is `xian`
/// or `xi an`), so this returns every plausible reading and the caller ORs them.
enum PinyinQuery {

    /// Longer pieces are not pinyin anyone types, and bounding the input bounds the search.
    static let maxLetters = 40
    /// Upper bound on the alternatives one piece expands to.
    static let maxPhrases = 8

    /// Every way to read `piece` as a run of characters, fewest characters first. Empty when the
    /// piece cannot be pinyin — anything but ASCII letters and `'`, or too long.
    ///
    /// A unit is a full syllable, a bare initial (`z`, or `zh` / `ch` / `sh`, which the index
    /// only knows by their first letter), or — last unit only, since the query is still being
    /// typed — any prefix of a syllable. `'` forces a boundary, as in `xi'an`.
    ///
    /// Only readings within one unit of the fewest are kept: `xian` gives `xian` and `xi an`,
    /// but `zhongguo` never falls apart into `z h o n g …`.
    static func phrases(for piece: String) -> [[String]] {
        var letters: [Character] = []
        var boundaries: Set<Int> = []
        for character in piece.lowercased() {
            if character == "'" {
                boundaries.insert(letters.count)
            } else if character.isASCII && character.isLetter {
                letters.append(character)
            } else {
                return []
            }
        }
        guard !letters.isEmpty, letters.count <= maxLetters else { return [] }

        let units = (0..<letters.count).map { unitsStarting(at: $0, in: letters, boundaries: boundaries) }

        // Fewest units that cover letters[i...]; `Int.max` where no reading exists.
        var fewest = [Int](repeating: .max, count: letters.count + 1)
        fewest[letters.count] = 0
        for start in stride(from: letters.count - 1, through: 0, by: -1) {
            for unit in units[start] where fewest[unit.end] != .max {
                fewest[start] = min(fewest[start], fewest[unit.end] + 1)
            }
        }
        guard fewest[0] != .max else { return [] }

        let budget = fewest[0] + 1
        var found: [[String]] = []
        var seen: Set<[String]> = []
        var path: [String] = []

        func walk(from start: Int) {
            guard found.count < maxPhrases * 4 else { return }
            guard start < letters.count else {
                if seen.insert(path).inserted { found.append(path) }
                return
            }
            for unit in units[start] where fewest[unit.end] != .max
                && path.count + 1 + fewest[unit.end] <= budget {
                path.append(unit.token)
                walk(from: unit.end)
                path.removeLast()
            }
        }
        walk(from: 0)

        // Fewer characters first; among equals, prefer whole syllables over bare initials.
        return found
            .sorted { ($0.count, $0.filter { $0.count == 1 }.count) < ($1.count, $1.filter { $0.count == 1 }.count) }
            .prefix(maxPhrases)
            .map { $0 }
    }
}

// MARK: - Units
private extension PinyinQuery {

    struct Unit {
        /// What the index holds for this character: a syllable, an initial, or a prefix.
        let token: String
        /// Index one past the unit's last letter.
        let end: Int
    }

    static let initials: Set<Character> = Set("bcdfghjklmnpqrstwxyz")
    static let retroflexInitials: [String: String] = ["zh": "z", "ch": "c", "sh": "s"]
    static let longestSyllable = 6

    static func unitsStarting(at start: Int, in letters: [Character], boundaries: Set<Int>) -> [Unit] {
        var units: [Unit] = []
        var tokens: Set<String> = []

        func add(_ token: String, end: Int) {
            if tokens.insert("\(token)|\(end)").inserted {
                units.append(Unit(token: token, end: end))
            }
        }

        for length in 1...min(longestSyllable, letters.count - start) {
            let end = start + length
            // A unit may not straddle a `'`.
            if length > 1 && ((start + 1)..<end).contains(where: boundaries.contains) { break }

            let text = String(letters[start..<end])
            if syllables.contains(text) || (end == letters.count && syllablePrefixes.contains(text)) {
                add(text, end: end)
            }
            if length == 1 && initials.contains(letters[start]) {
                add(text, end: end)
            }
            if let initial = retroflexInitials[text] {
                add(initial, end: end)
            }
        }
        return units
    }

    /// Every toneless reading in `Resources/pinyin.txt` (ü spelled `v`). Kept in step with the
    /// dictionary by hand — regenerate it with `script/gen_pinyin_dict.py` and diff the set.
    static let syllables: Set<String> = Set("""
    a ai an ang ao ba bai ban bang bao bei ben beng bi bian biao bie bin bing bo bu ca cai can cang \
    cao ce cen ceng cha chai chan chang chao che chen cheng chi chong chou chu chua chuai chuan \
    chuang chui chun chuo ci cong cou cu cuan cui cun cuo da dai dan dang dao de dei den deng di dia \
    dian diao die ding diu dong dou du duan dui dun duo e ei en eng er fa fan fang fei fen feng fiao \
    fo fou fu ga gai gan gang gao ge gei gen geng gong gou gu gua guai guan guang gui gun guo ha hai \
    han hang hao he hei hen heng hm hng hong hou hu hua huai huan huang hui hun huo ji jia jian jiang \
    jiao jie jin jing jiong jiu ju juan jue jun ka kai kan kang kao ke kei ken keng kong kou ku kua \
    kuai kuan kuang kui kun kuo la lai lan lang lao le lei len leng li lia lian liang liao lie lin \
    ling liu lo long lou lu luan lun luo lv lve m ma mai man mang mao me mei men meng mi mian miao mie \
    min ming miu mo mou mu n na nai nan nang nao ne nei nen neng ng ni nia nian niang niao nie nin \
    ning niu nong nou nu nuan nun nuo nv nve o ou pa pai pan pang pao pei pen peng pi pian piao pie \
    pin ping po pou pu qi qia qian qiang qiao qie qin qing qiong qiu qu quan que qun ran rang rao re \
    ren reng ri rong rou ru rua ruan rui run ruo sa sai san sang sao se sen seng sha shai shan shang \
    shao she shei shen sheng shi shou shu shua shuai shuan shuang shui shun shuo si song sou su suan \
    sui sun suo ta tai tan tang tao te tei teng ti tian tiao tie ting tong tou tu tuan tui tun tuo wa \
    wai wan wang wei wen weng wo wu xi xia xian xiang xiao xie xin xing xiong xiu xu xuan xue xun ya \
    yan yang yao ye yi yin ying yo yong you yu yuan yue yun za zai zan zang zao ze zei zen zeng zha \
    zhai zhan zhang zhao zhe zhei zhen zheng zhi zhong zhou zhu zhua zhuai zhuan zhuang zhui zhun \
    zhuo zi zong zou zu zuan zui zun zuo
    """.split(separator: " ").map(String.init))

    static let syllablePrefixes: Set<String> = Set(syllables.flatMap { syllable in
        (1...syllable.count).map { String(syllable.prefix($0)) }
    })
}
