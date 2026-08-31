import Foundation

/// 課題を層へ動かした結果。
public enum FocusMoveResult {
    /// そのまま適用できる。値は**更新が必要な課題だけ**(動いていない課題は含まない)。
    case apply(updated: [Issue])
    /// 重点が埋まっている。どれと入れ替えるかユーザーに選ばせる。値は現在の重点 3 件。
    case needsSwap(candidates: [Issue])

    /// `.apply` のときの更新対象。`.needsSwap` なら nil。
    public var updatedIssues: [Issue]? {
        switch self {
        case .apply(let updated): return updated
        case .needsSwap: return nil
        }
    }

    /// `.needsSwap` のときの入れ替え候補。`.apply` なら nil。
    public var swapCandidates: [Issue]? {
        switch self {
        case .apply: return nil
        case .needsSwap(let candidates): return candidates
        }
    }
}

/// 重点 3 枠と層の並びの管理(§3.3 / §7.4)。
///
/// 純粋関数。課題の集合を受け取り、**更新が必要な課題だけ**を返す。保存はしない。
///
/// 返す集合を絞るのは効率のためだけではない。`IssueRepository.update` は
/// `updated_at` を更新するので、動いていない課題まで保存すると §4.2 の
/// 「放置期間」判定がリセットされ、忘れかけの課題が浮上しなくなる。
///
/// 渡す `issues` は判定の母集団そのもの。重点の空き枠もこの集合から数えるので、
/// アーカイブ済みを含めない集合(`fetch(statuses: [.inbox, .active])`)を渡すこと。
public struct FocusBoard {
    private init() {
    }

    /// 重点の上限(§3.3)。
    public static let focusCapacity = 3

    /// 空いている枠。**負にならない**(3 枠を超えて入っていても 0)。
    ///
    /// 組み替えモードの「あと N 枠」に使う(1.9)。
    public static func remainingSlots(focusCount: Int) -> Int {
        let remaining = FocusBoard.focusCapacity - focusCount
        return remaining > 0 ? remaining : 0
    }

    /// 組み替え画面に行く意味があるか(1.9)。
    ///
    /// **外す相手がいるだけでも意味がある** —— 候補が無くても、今の重点を外して
    /// 空にする操作はできる。両方 0 のときだけ空振りなので、そのときは導線を出さない。
    public static func canReshuffle(focusCount: Int, candidateCount: Int) -> Bool {
        return focusCount > 0 || candidateCount > 0
    }

    /// 課題を指定の層の指定位置へ動かす。層内の並び替えも同じ入口。
    ///
    /// 重点へ上げようとして 3 枠が埋まっていれば `.needsSwap` を返し、**何も変更しない**。
    /// 既に重点にある課題の並び替えは 4 件目にならないので上限に掛からない。
    ///
    /// - Parameter index: 移動先の層での位置。範囲外は先頭 / 末尾に丸める。
    public static func move(_ issue: Issue, to tier: Tier, at index: Int, in issues: [Issue]) -> FocusMoveResult {
        if tier == Tier.focus && issue.tier != Tier.focus {
            let occupied = FocusBoard.issues(in: Tier.focus, of: issues, excluding: issue.id)
            if occupied.count >= FocusBoard.focusCapacity {
                return FocusMoveResult.needsSwap(candidates: occupied)
            }
        }

        var moved = issue
        moved.tier = tier

        var destination = FocusBoard.issues(in: tier, of: issues, excluding: issue.id)
        destination.insert(moved, at: FocusBoard.clamp(index, upperBound: destination.count))

        var updated: [Issue] = []
        updated.append(contentsOf: FocusBoard.renumbered(destination, comparedTo: issues))
        if tier != issue.tier {
            let source = FocusBoard.issues(in: issue.tier, of: issues, excluding: issue.id)
            updated.append(contentsOf: FocusBoard.renumbered(source, comparedTo: issues))
        }
        return FocusMoveResult.apply(updated: updated)
    }

    /// 入れ替えを確定する。`demoting` が `next` の末尾に降り、`promoting` が空いた枠に入る。
    ///
    /// 昇格する課題は降りた課題のいた位置に入るので、残りの 2 件は動かない。
    ///
    /// 重点に無い課題を降ろそうとした場合や、既に重点にある課題を上げようとした場合は
    /// 何もしない(空を返す)。重点が 4 件になる入力を通さないため。
    public static func swap(promoting: Issue, demoting: Issue, in issues: [Issue]) -> [Issue] {
        if promoting.tier == Tier.focus || demoting.tier != Tier.focus {
            return []
        }

        var promoted = promoting
        promoted.tier = Tier.focus
        var demoted = demoting
        demoted.tier = Tier.next

        // 重点: demoting のいた枠を promoting で置き換える
        var focusList: [Issue] = []
        for current in FocusBoard.issues(in: Tier.focus, of: issues, excluding: nil) {
            if current.id == demoting.id {
                focusList.append(promoted)
            } else {
                focusList.append(current)
            }
        }

        // next: promoting を抜き、降りた課題を末尾に足す
        var nextList = FocusBoard.issues(in: Tier.next, of: issues, excluding: promoting.id)
        nextList.append(demoted)

        var updated: [Issue] = []
        updated.append(contentsOf: FocusBoard.renumbered(focusList, comparedTo: issues))
        updated.append(contentsOf: FocusBoard.renumbered(nextList, comparedTo: issues))
        // someday から上げた場合は元の層も詰める
        if promoting.tier != Tier.next {
            let source = FocusBoard.issues(in: promoting.tier, of: issues, excluding: promoting.id)
            updated.append(contentsOf: FocusBoard.renumbered(source, comparedTo: issues))
        }
        return updated
    }

    // MARK: - 内部

    /// 層に属する課題を並び順で返す。`excluding` に渡した id は除く。
    private static func issues(in tier: Tier, of issues: [Issue], excluding excludedID: Int64?) -> [Issue] {
        var result: [Issue] = []
        for issue in issues {
            if issue.tier != tier {
                continue
            }
            if let excludedID = excludedID, issue.id == excludedID {
                continue
            }
            result.append(issue)
        }
        return FocusBoard.sortedByPosition(result)
    }

    /// 手動並び順。同順なら登録順(id)で安定させる。
    ///
    /// Skip の `sorted(by:)` は変更不可のリストを包んだ配列を返すため、
    /// そのまま `insert` / `append` すると Android で
    /// `UnsupportedOperationException` になる。新しい配列に写してから返す。
    private static func sortedByPosition(_ issues: [Issue]) -> [Issue] {
        let ordered = issues.sorted(by: { first, second in
            if first.sortOrder != second.sortOrder {
                return first.sortOrder < second.sortOrder
            }
            return first.id < second.id
        })
        var mutable: [Issue] = []
        mutable.append(contentsOf: ordered)
        return mutable
    }

    /// 並びに沿って `sortOrder` を 0 から振り直し、**元と変わったものだけ**返す。
    private static func renumbered(_ ordered: [Issue], comparedTo original: [Issue]) -> [Issue] {
        var changed: [Issue] = []
        for index in 0..<ordered.count {
            var candidate = ordered[index]
            candidate.sortOrder = index
            if FocusBoard.hasChanged(candidate, comparedTo: original) {
                changed.append(candidate)
            }
        }
        return changed
    }

    private static func hasChanged(_ candidate: Issue, comparedTo original: [Issue]) -> Bool {
        for issue in original {
            if issue.id == candidate.id {
                return issue.tier != candidate.tier || issue.sortOrder != candidate.sortOrder
            }
        }
        return true
    }

    private static func clamp(_ index: Int, upperBound: Int) -> Int {
        if index < 0 {
            return 0
        }
        if index > upperBound {
            return upperBound
        }
        return index
    }
}
