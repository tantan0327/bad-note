import Foundation

/// カウントダウンの文言(§5.2)。「あと 42日 / 12回」。
///
/// ホーム(`HomeView`)と大会詳細(`CompetitionDetailView`)の両方が出すので、
/// ここ 1 か所で決める。**回数が nil のときは日数だけ** ——
/// 練習予定日が未設定で、数える根拠が無い状態を表す。
public struct RemainingText {
    private init() {
    }

    public static func text(remainingDays: Int, remainingPractices: Int?) -> String {
        let days = remainingDays == 0 ? "今日" : "あと \(remainingDays)日"
        if let practices = remainingPractices {
            return "\(days) / \(practices)回"
        }
        return days
    }
}
