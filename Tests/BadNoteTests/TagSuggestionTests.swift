import XCTest
import Foundation
@testable import BadNote

/// 既に使ったタグを候補として出す(2026-10-28)。
///
/// **同じ意味のタグが何個もできるのを防ぐのが目的。**
/// 「バックハンド」と「バックハンド 」と「ばっくはんど」が別々に増えると、
/// タグで絞り込んでも全部は拾えない。
final class TagSuggestionTests: XCTestCase {

    private func tags(_ names: [String]) -> [Tag] {
        var result: [Tag] = []
        var id: Int64 = 1
        for name in names {
            result.append(Tag(id: id, name: name))
            id += 1
        }
        return result
    }

    private func names(_ tags: [Tag]) -> [String] {
        var result: [String] = []
        for tag in tags {
            result.append(tag.name)
        }
        return result
    }

    // MARK: - まだ何も打っていないとき

    /// 入力が空なら、使ったことのあるタグをそのまま並べる。
    /// **ここが本題** —— 打たずに選べることに意味がある。
    func testShowsEveryTagWhenNothingTyped() {
        let all = tags(["バックハンド", "フットワーク", "メンタル"])

        let shown = TagSuggestion.candidates(all: all, attached: [], query: "")

        XCTAssertEqual(["バックハンド", "フットワーク", "メンタル"], names(shown))
    }

    /// **既に付けたタグは候補に出さない。** 押しても何も起きない行になる。
    func testExcludesTagsAlreadyAttached() {
        let all = tags(["バックハンド", "フットワーク"])

        let shown = TagSuggestion.candidates(all: all, attached: [all[0]], query: "")

        XCTAssertEqual(["フットワーク"], names(shown))
    }

    // MARK: - 打っているとき

    /// 打った文字を含むものだけに絞る。
    func testFiltersByQuery() {
        let all = tags(["バックハンド", "バックアウト", "フットワーク"])

        let shown = TagSuggestion.candidates(all: all, attached: [], query: "バック")

        XCTAssertEqual(["バックハンド", "バックアウト"], names(shown))
    }

    /// 途中に含まれていても拾う(前方一致に限らない)。
    func testMatchesInTheMiddle() {
        let all = tags(["レシーブのバックハンド"])

        let shown = TagSuggestion.candidates(all: all, attached: [], query: "バック")

        XCTAssertEqual(["レシーブのバックハンド"], names(shown))
    }

    /// 前後の空白は無視する。欄に空白だけ入っている状態は「何も打っていない」。
    func testWhitespaceOnlyQueryShowsEverything() {
        let all = tags(["バックハンド", "フットワーク"])

        let shown = TagSuggestion.candidates(all: all, attached: [], query: "   ")

        XCTAssertEqual(["バックハンド", "フットワーク"], names(shown))
    }

    /// **打った文字と完全に同じタグは出さない。** すぐ隣の「追加」が同じことをする。
    /// 部分一致する別のタグは残る。
    func testHidesTheExactMatchButKeepsLongerOnes() {
        let all = tags(["バック", "バックハンド"])

        let shown = TagSuggestion.candidates(all: all, attached: [], query: "バック")

        XCTAssertEqual(["バックハンド"], names(shown))
    }

    /// 一致しなければ空。画面側は候補の行ごと出さない。
    func testNoMatchGivesNothing() {
        let all = tags(["バックハンド"])

        XCTAssertEqual([String](), names(TagSuggestion.candidates(all: all, attached: [], query: "サーブ")))
    }

    // MARK: - 数を絞る

    /// **出しすぎない。** タグが増えても入力欄が候補で埋まらないようにする。
    func testStopsAtTheLimit() {
        var many: [String] = []
        for index in 0..<30 {
            many.append("タグ\(index)")
        }

        let shown = TagSuggestion.candidates(all: tags(many), attached: [], query: "")

        XCTAssertEqual(TagSuggestion.limit, shown.count)
    }

    func testLimitIsEight() {
        XCTAssertEqual(8, TagSuggestion.limit)
    }

    // MARK: - 端

    func testNoTagsGivesNothing() {
        XCTAssertEqual([String](), names(TagSuggestion.candidates(all: [], attached: [], query: "")))
    }

    /// 全部付け終わっていれば候補は無い。
    func testEverythingAttachedGivesNothing() {
        let all = tags(["バックハンド", "フットワーク"])

        XCTAssertEqual([String](), names(TagSuggestion.candidates(all: all, attached: all, query: "")))
    }

    /// 並びは渡された順のまま。**使用頻度で並べ替えたりしない** ——
    /// `TagRepository.fetchAll` は名前順で返すので、探す場所として安定する
    func testKeepsTheGivenOrder() {
        let all = tags(["ふ", "あ", "か"])

        XCTAssertEqual(["ふ", "あ", "か"], names(TagSuggestion.candidates(all: all, attached: [], query: "")))
    }
}
