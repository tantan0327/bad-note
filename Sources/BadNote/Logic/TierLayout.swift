import Foundation

/// 3 層を畳んだ 1 行分。見出しか課題のどちらか。
public struct TierRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let tier: Tier
    /// nil なら層の見出し
    public let issue: Issue?

    public var isHeader: Bool {
        return issue == nil
    }

    public static func header(_ tier: Tier) -> TierRow {
        return TierRow(id: "header-" + tier.rawValue, tier: tier, issue: nil)
    }

    public static func item(_ issue: Issue) -> TierRow {
        return TierRow(id: "issue-\(issue.id)", tier: issue.tier, issue: issue)
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

    /// 見出し込みの 1 本の並びを作る。**空の層でも見出しは残す** —— 移動先として選べる必要がある。
    public static func rows(focus: [Issue], next: [Issue], someday: [Issue]) -> [TierRow] {
        var rows: [TierRow] = []
        rows.append(TierRow.header(Tier.focus))
        for issue in focus {
            rows.append(TierRow.item(issue))
        }
        rows.append(TierRow.header(Tier.next))
        for issue in next {
            rows.append(TierRow.item(issue))
        }
        rows.append(TierRow.header(Tier.someday))
        for issue in someday {
            rows.append(TierRow.item(issue))
        }
        return rows
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
        if rows[fromOffset].isHeader {
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
            } else {
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
