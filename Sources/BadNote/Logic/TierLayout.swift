import Foundation

/// 3 層を畳んだ 1 行分。
public enum TierRowKind: Hashable, Sendable {
    /// 層の見出し。動かせない
    case header
    /// 空の層の落下先。動かせないが、**ドラッグの落とし先にはなる**
    case placeholder
    /// 畳んだ層の落下先。`placeholder` と分けているのは**表示が違う**ため
    /// (空の層は「まだありません」、畳んだ層は畳んでいる件数)
    case folded
    /// 重点の空き枠(1.10)。ホームと同じ「空き枠 / 選ぶ」を一覧にも出す。
    /// `placeholder` と分けているのは**表示が違う**ため
    /// (空の層は「まだありません」、空き枠は「空き枠」+ 選ぶ導線)
    case slot
    /// 課題そのもの
    case issue
}

public struct TierRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let tier: Tier
    public let kind: TierRowKind
    /// `kind == .issue` のときだけ入る
    public let issue: Issue?

    public var isHeader: Bool {
        return kind == TierRowKind.header
    }

    public var isPlaceholder: Bool {
        return kind == TierRowKind.placeholder
    }

    public var isFolded: Bool {
        return kind == TierRowKind.folded
    }

    public var isSlot: Bool {
        return kind == TierRowKind.slot
    }

    public static func header(_ tier: Tier) -> TierRow {
        return TierRow(id: "header-" + tier.rawValue, tier: tier, kind: .header, issue: nil)
    }

    /// 空の層に置く落下先。**これが無いと空の層にドラッグできない。**
    public static func placeholder(_ tier: Tier) -> TierRow {
        return TierRow(id: "empty-" + tier.rawValue, tier: tier, kind: .placeholder, issue: nil)
    }

    /// 畳んだ層の落下先(2026-10-18)。**空の層とは別物。**
    /// 同じ行を使うと「いつか 12件」の真下に「まだありません」と出て、
    /// 畳んだ本人にも矛盾して見える。
    public static func folded(_ tier: Tier) -> TierRow {
        return TierRow(id: "folded-" + tier.rawValue, tier: tier, kind: .folded, issue: nil)
    }

    public static func item(_ issue: Issue) -> TierRow {
        return TierRow(id: "issue-\(issue.id)", tier: issue.tier, kind: .issue, issue: issue)
    }

    /// 重点の空き枠(1.10)。**落下先にもなる**が、位置には数えない
    /// (`TierLayout.target` は課題の行だけ数えるため)。
    public static func slot(_ tier: Tier, index: Int) -> TierRow {
        return TierRow(id: "slot-" + tier.rawValue + "-\(index)", tier: tier, kind: .slot, issue: nil)
    }
}

/// ドラッグの移動先。
public struct TierDropTarget: Hashable, Sendable {
    public let tier: Tier
    public let index: Int
}

/// 3 層を 1 つの並びに畳み、ドラッグの落下位置から移動先を逆算する(§7.4)。
///
/// SwiftUI の `onMove` は**ひとつの `ForEach` の中でしか働かない**ため、
/// 層をまたぐドラッグには 3 層を 1 本のリストにする必要がある。
/// 見出しも行として並べ、落とした位置の直前の見出しが移動先の層になる。
///
/// 純粋関数。
public struct TierLayout {
    private init() {
    }

    /// 層の並び順(上から)。
    public static let tiers = [Tier.focus, Tier.next, Tier.someday]

    /// 畳むことを勧める件数(2026-10-12)。
    ///
    /// これを超えた層は**既定で畳む**。40 件の「いつか」が開いたまま並ぶと、
    /// 一覧が 1 本の長いリストになって、上の 2 層が視界から消える。
    /// 小さい層まで畳むと、ただ隠されただけになるので閾値を置く。
    public static let collapseThreshold = 8

    /// 既定で畳んでおく層。**「いつか」が溜まっているときだけ。**
    ///
    /// 重点は 3 件まで、次にやるは本人がいま選んでいる最中のものなので畳まない。
    public static func initiallyCollapsed(somedayCount: Int) -> [Tier] {
        if somedayCount > TierLayout.collapseThreshold {
            return [Tier.someday]
        }
        return [Tier]()
    }

    /// 見出し込みの 1 本の並びを作る。
    ///
    /// **空の層には落下先の行を 1 つ置く。** 見出しは動かせないので、
    /// 見出しだけだとその層がドラッグの落とし先にならない。
    /// **重点には空き枠の行を並べる**(1.10)。ホームが「空き枠 / 選ぶ」を 3 枠分出すのに
    /// 一覧は見出しの「1/3」だけ、という見せ方の食い違いを無くす。
    /// 空き枠は落下先にもなるので、ドラッグで運ぶ的にもなる。
    ///
    /// ただし **3 層すべて空のときは空き枠を出さない** —— 課題が 1 つも無い人に
    /// 空き枠だけ 3 つ見せても意味が無い(初回の案内はホームが持つ。4.1)。
    ///
    /// **畳んだ層は見出しと落下先だけにする**(2026-10-12)。中身は消えない。
    public static func rows(focus: [Issue], next: [Issue], someday: [Issue],
                            collapsed: [Tier] = [Tier]()) -> [TierRow] {
        let isEmptyBoard = focus.isEmpty && next.isEmpty && someday.isEmpty
        var rows: [TierRow] = []
        if isEmptyBoard {
            // 盤面が空のときは従来どおり「まだありません」の落下先だけ
            TierLayout.append(tier: Tier.focus, issues: focus, collapsed: collapsed, to: &rows)
        } else {
            rows.append(TierRow.header(Tier.focus))
            if !TierLayout.isCollapsed(Tier.focus, in: collapsed) {
                for issue in focus {
                    rows.append(TierRow.item(issue))
                }
                // 空き枠が落下先を兼ねるので、重点には placeholder を置かない
                let slots = FocusBoard.remainingSlots(focusCount: focus.count)
                for index in 0..<slots {
                    rows.append(TierRow.slot(Tier.focus, index: index))
                }
            } else {
                // **畳んだ層にも落下先を 1 つ残す。** 無いとドラッグで運び込めなくなる
                rows.append(TierRow.folded(Tier.focus))
            }
        }
        TierLayout.append(tier: Tier.next, issues: next, collapsed: collapsed, to: &rows)
        TierLayout.append(tier: Tier.someday, issues: someday, collapsed: collapsed, to: &rows)
        return rows
    }

    /// `[Tier]` の `contains` は書かずに自前で回す(`PracticePlan` と同じ理由)。
    static func isCollapsed(_ tier: Tier, in collapsed: [Tier]) -> Bool {
        for candidate in collapsed {
            if candidate == tier {
                return true
            }
        }
        return false
    }

    private static func append(tier: Tier, issues: [Issue], collapsed: [Tier], to rows: inout [TierRow]) {
        rows.append(TierRow.header(tier))
        // 落下先の行を 1 つだけ置く。**畳んだ層と空の層は別の行**(表示が違う)。
        // **空のほうが優先** —— 畳んでいても 0 件なら「0件を畳んでいます」になってしまう
        if issues.isEmpty {
            rows.append(TierRow.placeholder(tier))
            return
        }
        if TierLayout.isCollapsed(tier, in: collapsed) {
            rows.append(TierRow.folded(tier))
            return
        }
        for issue in issues {
            rows.append(TierRow.item(issue))
        }
    }

    /// 落とした位置から移動先の層と、その中での位置を求める。
    ///
    /// - 見出しを動かそうとしたら nil(並べ替えの対象外)
    /// - **動かしている行自身は数えない。** `FocusBoard.move` は対象を抜いてから差し込むため、
    ///   抜いた後の位置を渡す必要がある
    ///
    /// - Parameter toOffset: SwiftUI の `onMove` が渡す挿入位置(元の並びでの添字)。
    public static func target(movingFrom fromOffset: Int, toOffset: Int, rows: [TierRow]) -> TierDropTarget? {
        if fromOffset < 0 || fromOffset >= rows.count {
            return nil
        }
        // 見出しと落下先の行は動かせない
        if rows[fromOffset].kind != TierRowKind.issue {
            return nil
        }

        var limit = toOffset
        if limit < 0 {
            limit = 0
        }
        if limit > rows.count {
            limit = rows.count
        }

        var tier: Tier? = nil
        var index = 0
        for position in 0..<limit {
            if position == fromOffset {
                continue
            }
            let row = rows[position]
            if row.isHeader {
                tier = row.tier
                index = 0
            } else if row.kind == TierRowKind.issue {
                // 落下先の行は課題ではないので数えない
                index += 1
            }
        }
        // 最初の見出しより前に落とされたら、最上位の層の先頭
        guard let tier = tier else {
            return TierDropTarget(tier: Tier.focus, index: 0)
        }
        return TierDropTarget(tier: tier, index: index)
    }
}
