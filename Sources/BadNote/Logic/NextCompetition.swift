import Foundation

/// ホームに添える「次の大会」の選び方(§7.5)。
///
/// 目標大会が遠いと、その手前にある大会(練習試合・市民大会)に意味づけが無くなる。
/// **目標大会を除いた、いちばん近い未来の大会**を 1 件だけ選んで的にする。
/// 目標大会そのものはホームで別枠(カウントダウン)なので候補から外す。
public enum NextCompetition {

    /// - Parameters:
    ///   - upcoming: 候補。`CompetitionRepository.fetchUpcoming(asOf:)` の結果をそのまま渡せる
    ///   - targetIds: 種目ごとの目標大会の id(除外する)
    ///   - asOf: 基準時刻。**この時刻ちょうどの大会は「これから」に含む**
    ///     (当日の大会を当日いっぱい先の予定として扱う。fetchUpcoming と同じ約束)
    public static func pick(upcoming: [Competition], targetIds: [Int64], asOf: Date) -> Competition? {
        var best: Competition? = nil
        for candidate in upcoming {
            if candidate.eventDate < asOf {
                continue
            }
            if targetIds.contains(candidate.id) {
                continue
            }
            guard let current = best else {
                best = candidate
                continue
            }
            // 同じ日なら先に登録した方(id 小)。決めておかないと開くたびに入れ替わって見える
            if candidate.eventDate < current.eventDate {
                best = candidate
            } else if candidate.eventDate == current.eventDate && candidate.id < current.id {
                best = candidate
            }
        }
        return best
    }
}
