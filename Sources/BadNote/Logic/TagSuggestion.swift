import Foundation

/// 既に使ったタグを候補として出す(2026-10-28)。
///
/// **同じ意味のタグが何個もできるのを防ぐのが目的。**
/// それまでタグは毎回手で打つしかなく、「バックハンド」と「バックハンド 」と
/// 「ばっくはんど」が別々のタグとして増えていく。そうなるとタグで絞り込んでも全部は拾えない。
///
/// 打たずに選べることが本題なので、**入力が空でも候補を出す**。
/// 絞り込み(§7.4 の検索)と違い、ここは「思い出す」ための場所。
public enum TagSuggestion {

    /// 一度に出す上限。**タグが増えても入力欄が候補で埋まらないようにする。**
    ///
    /// 8 は、3 文字前後のタグなら折り返して 2〜3 行に収まる数。
    /// これを超えるほど候補が要るなら、打って絞り込むほうが早い。
    public static let limit = 8

    /// 出す候補を選ぶ。
    ///
    /// - Parameters:
    ///   - all: 使ったことのあるタグ全部(`TagRepository.fetchAll`。名前順)
    ///   - attached: その課題に既に付いているタグ
    ///   - query: 入力中の文字
    ///
    /// **並べ替えはしない。** 渡された順のまま返す ——
    /// `fetchAll` が名前順なので、探す場所として位置が安定する。
    /// 使用頻度で並べ替えると、同じタグが毎回違う位置に来て選びにくい。
    public static func candidates(all: [Tag], attached: [Tag], query: String) -> [Tag] {
        let text = query.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        var result: [Tag] = []
        for tag in all {
            if result.count >= TagSuggestion.limit {
                break
            }
            if TagSuggestion.isAttached(tag, to: attached) {
                continue
            }
            if text.isEmpty {
                result.append(tag)
                continue
            }
            // **打った文字と完全に同じものは出さない。**
            // すぐ隣の「追加」が同じことをするので、候補に出すと 2 つの道ができる
            if tag.name == text {
                continue
            }
            if tag.name.contains(text) {
                result.append(tag)
            }
        }
        return result
    }

    static func isAttached(_ tag: Tag, to attached: [Tag]) -> Bool {
        for existing in attached {
            if existing.id == tag.id {
                return true
            }
        }
        return false
    }
}
