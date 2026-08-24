import Foundation

/// 積み上げの「節目」(1.2 / モチベーション設計)。
///
/// 達成済みのコレクションに加えて、**次の節目 1 つとそこまでの進み具合**を見せる
/// (2026-08-24。1 万時間だけが遠くに見えて途方もない、の対策)。
/// §5.3 の線引きは守る —— 「あと N 時間」の文言・締め切り・ペースは出さない。
/// 勾配はバーの満ち具合だけで伝える。
public enum Milestone {
    /// 節目(時間)の階段。最初を 1 時間にして早い達成感を作り、
    /// 最終段が **1 万時間(1 万時間の法則)**。倍率をおおむね 2〜2.5 倍に保つ
    /// (1000 → いきなり 1 万、の欠落を 2000・5000 で埋めた。2026-08-24)。
    public static let hourThresholds: [Int] = [1, 5, 10, 25, 50, 100, 200, 500, 1000, 2000, 5000, 10_000]

    /// 通算(分)から、到達済みの節目(時間)を **小さい順** に返す。
    public static func reachedHours(minutes: Int) -> [Int] {
        var result: [Int] = []
        for hours in hourThresholds {
            if minutes >= hours * 60 {
                result.append(hours)
            }
        }
        return result
    }

    /// 次の節目(時間)。境界ちょうどは到達済み。全段登り切ったら nil。
    public static func nextHours(minutes: Int) -> Int? {
        for hours in hourThresholds {
            if minutes < hours * 60 {
                return hours
            }
        }
        return nil
    }

    /// 次の節目までの進み具合(0.0〜1.0)。
    ///
    /// 区間の起点は**直前の節目**(まだ無ければ 0)。累計全体からの割合にすると
    /// 段が上がるほどバーが動かなくなり、勾配が見えなくなる。全段登り切ったら 1.0。
    public static func progressToNext(minutes: Int) -> Double {
        guard let next = nextHours(minutes: minutes) else {
            return 1.0
        }
        let base = reachedHours(minutes: minutes).last ?? 0
        let span = (next - base) * 60
        let climbed = minutes - base * 60
        // Int 同士の除算にしない(Kotlin でも 0 に切り捨てられる)
        let progress = Double(climbed) / Double(span)
        return min(max(progress, 0.0), 1.0)
    }

    /// (from, to] の間に**新たに越えた**節目(時間)を小さい順に返す。
    ///
    /// 保存の瞬間に祝うための判定。変化なし・逆行(記録の削除など)は空。
    public static func crossedHours(fromMinutes: Int, toMinutes: Int) -> [Int] {
        if fromMinutes >= toMinutes {
            return []
        }
        var result: [Int] = []
        for hours in hourThresholds {
            let boundary = hours * 60
            if fromMinutes < boundary && toMinutes >= boundary {
                result.append(hours)
            }
        }
        return result
    }
}
