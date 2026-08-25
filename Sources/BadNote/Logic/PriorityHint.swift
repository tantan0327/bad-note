import Foundation

/// 影響度 × コストから出す手がかり(§3.4)。
///
/// 影響度とコストは入力させるのに、これまで**課題詳細の「属性」の奥に言葉で出るだけ**で、
/// 選ぶ場面(課題一覧・組み替え)には現れなかった。入力を求めておいて判断に返していない
/// 状態だったので、目印として拾い上げる(2026-08-25)。
///
/// **アプリは解釈や警告を出さない**(CLAUDE.md)ので、並べ替えも自動選択もしない。
/// 目印を 1 つ添えるだけで、選ぶのは本人。
public enum PriorityHint: Hashable {
    /// 影響度が大きく、すぐ直る —— **重点に入れるべき候補**(§3.4)。
    case quickWin
    /// 影響度は大きいが、直るのにシーズン単位でかかる(§3.4)。
    /// 大会に間に合わない可能性を、責めずに知らせるための目印。
    case seasonLong

    /// 未入力(どちらか欠けている)なら nil。入力は任意なので欠けているのが普通。
    ///
    /// **影響度が大きい課題にだけ付ける。** 影響度が小さい課題にも付けると
    /// 目印だらけになって、目印としての意味が無くなる。
    public static func forIssue(impact: Int?, cost: Int?) -> PriorityHint? {
        guard let impact = impact, let cost = cost else {
            return nil
        }
        if impact < 3 {
            return nil
        }
        if cost == 1 {
            return PriorityHint.quickWin
        }
        if cost == 3 {
            return PriorityHint.seasonLong
        }
        return nil
    }

    /// 表示は言葉にする(§3.4 数字は画面に出さない)。
    public var displayName: String {
        switch self {
        case .quickWin: return "すぐ効く"
        case .seasonLong: return "シーズン単位"
        }
    }
}
