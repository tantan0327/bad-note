import Foundation

/// 大会後の振り返り(§6 `competition_review`)。**種目ごとに 1 セット**(§7.5)。
///
/// 4 つの問いはすべて任意。書けるところだけ書けばよい。
public struct CompetitionReview: Hashable, Identifiable {
    public var id: Int64
    public var competitionId: Int64
    public var discipline: Discipline
    /// 戦績・自由記述
    public var result: String?
    /// うまくいったことは何か
    public var wentWell: String?
    /// 理想の姿に近づくために次にやることは何か。ここから課題を登録できる(§7.5)
    public var nextAction: String?
    /// そのために必要なもの(人・道具・情報)は何か
    public var neededResources: String?
    public var createdAt: Date

    public init(id: Int64,
                competitionId: Int64,
                discipline: Discipline,
                result: String? = nil,
                wentWell: String? = nil,
                nextAction: String? = nil,
                neededResources: String? = nil,
                createdAt: Date) {
        self.id = id
        self.competitionId = competitionId
        self.discipline = discipline
        self.result = result
        self.wentWell = wentWell
        self.nextAction = nextAction
        self.neededResources = neededResources
        self.createdAt = createdAt
    }
}
