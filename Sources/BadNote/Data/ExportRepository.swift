import Foundation
import SkipSQL

/// 全データを JSON 1 つに書き出す(tasks.md 7.3)。
///
/// バックアップ用途。**テーブルの生の値をそのまま写す**(日付の変換も列の解釈もしない)。
/// 読み込み(復元)側がスキーマ差分を吸収できるよう、`schema_version`
/// (PRAGMA user_version)を封筒に入れる。
///
/// JSON は自前で組み立てる。JSONEncoder にしないのは、列構成をスキーマから
/// 自動で拾う(テーブルや列が増えても構造体を書き足さなくて済む)ためと、
/// 出力を 1 バイト単位で決定的にする(バックアップ同士を差分で比べられる)ため。
public final class ExportRepository {
    private let db: SQLContext
    private let timestamps = SQLTimestamp()

    public init(db: SQLContext) {
        self.db = db
    }

    /// 書き出すテーブル。親 → 子の順(復元時にこの順で入れれば外部キーを満たせる)。
    ///
    /// **マイグレーションでテーブルを足したらここにも足すこと**
    /// (`testTableListMatchesSchema` が入れ忘れを検出する)。
    public static let tables = [
        "issue", "tag", "issue_tag",
        "practice", "focus_record", "practice_plan",
        "competition", "competition_entry", "competition_review", "issue_competition",
        "vision", "level_change", "focus_span", "stale_flag",
        "training_menu", "training_log", "app_meta",
    ]

    /// 例:
    /// ```json
    /// {
    ///   "app": "BadNote",
    ///   "format": 1,
    ///   "schema_version": 10,
    ///   "exported_at": "2026-08-24T02:00:00Z",
    ///   "tables": {
    ///     "issue": [
    ///       { "id": 1, "coach_words": "ラケット面が下向き", ... }
    ///     ]
    ///   }
    /// }
    /// ```
    public func exportJSON(now: Date = Date()) throws -> String {
        var lines: [String] = []
        lines.append("{")
        lines.append("  \"app\": \"BadNote\",")
        lines.append("  \"format\": 1,")
        lines.append("  \"schema_version\": \(db.userVersion),")
        lines.append("  \"exported_at\": \(ExportRepository.quote(timestamps.text(from: now))),")
        lines.append("  \"tables\": {")
        for tableIndex in 0..<ExportRepository.tables.count {
            let table = ExportRepository.tables[tableIndex]
            let comma = tableIndex == ExportRepository.tables.count - 1 ? "" : ","
            let rows = try rowsJSON(table: table)
            if rows.isEmpty {
                lines.append("    \(ExportRepository.quote(table)): []\(comma)")
                continue
            }
            lines.append("    \(ExportRepository.quote(table)): [")
            for rowIndex in 0..<rows.count {
                let rowComma = rowIndex == rows.count - 1 ? "" : ","
                lines.append("      \(rows[rowIndex])\(rowComma)")
            }
            lines.append("    ]\(comma)")
        }
        lines.append("  }")
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    /// 1 テーブルの全行。1 行 = 1 つの JSON オブジェクト(テキスト 1 行)。
    ///
    /// 列名は SELECT 結果から拾うので、マイグレーションで列が増えても追従する。
    /// テーブル名は `tables` 定数からしか来ないため、プレースホルダにしなくてよい。
    private func rowsJSON(table: String) throws -> [String] {
        let statement = try db.prepare(sql: "SELECT * FROM \(table) ORDER BY rowid")
        defer { try? statement.close() }
        let columns = statement.columnNames
        var rows: [String] = []
        while try statement.next() {
            var fields: [String] = []
            for index in 0..<columns.count {
                let value = statement.value(at: Int32(index))
                fields.append("\(ExportRepository.quote(columns[index])): \(ExportRepository.json(value))")
            }
            rows.append("{ " + fields.joined(separator: ", ") + " }")
        }
        return rows
    }

    // MARK: - JSON の組み立て(純粋関数)

    /// JSON 文字列リテラル用のエスケープ。対象は `"` `\` 改行・復帰・タブ。
    ///
    /// それ以外の制御文字(U+0000〜U+001F)は TextField / TextEditor からは
    /// 入力できないので扱わない。
    public static func escape(_ raw: String) -> String {
        var text = raw
        text = text.replacingOccurrences(of: "\\", with: "\\\\")
        text = text.replacingOccurrences(of: "\"", with: "\\\"")
        text = text.replacingOccurrences(of: "\n", with: "\\n")
        text = text.replacingOccurrences(of: "\r", with: "\\r")
        text = text.replacingOccurrences(of: "\t", with: "\\t")
        return text
    }

    private static func quote(_ raw: String) -> String {
        return "\"" + escape(raw) + "\""
    }

    private static func json(_ value: SQLValue) -> String {
        switch value {
        case .long(let long):
            return long.description
        case .real(let real):
            return real.description
        case .text(let text):
            return quote(text)
        case .blob(let blob):
            // 現状のスキーマに BLOB 列は無い。将来増えても壊さないよう base64 で逃がす
            return quote(blob.base64EncodedString())
        case .null:
            return "null"
        }
    }
}
