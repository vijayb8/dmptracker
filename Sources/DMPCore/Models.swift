import Foundation

public enum Metric: String, Codable, CaseIterable, Identifiable, Sendable {
    case hba1c, systolic, diastolic, weight, ldl, glucose, fev1
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .hba1c: return "HbA1c"
        case .systolic: return "Blutdruck systolisch"
        case .diastolic: return "Blutdruck diastolisch"
        case .weight: return "Gewicht"
        case .ldl: return "LDL-Cholesterin"
        case .glucose: return "Glukose"
        case .fev1: return "FEV1"
        }
    }
    public var units: [String] {
        switch self {
        case .hba1c: return ["%", "mmol/mol"]
        case .systolic, .diastolic: return ["mmHg"]
        case .weight: return ["kg"]
        case .ldl, .glucose: return ["mg/dl", "mmol/l"]
        case .fev1: return ["l", "%"]
        }
    }
}
public struct Measurement: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var metric: Metric
    public var value: Double
    public var unit: String
    public var date: Date
    public var reportID: UUID?
    public var source: String
    public init(metric: Metric, value: Double, unit: String, date: Date, reportID: UUID? = nil, source: String = "Manuell erfasst") {
        self.metric = metric; self.value = value; self.unit = unit; self.date = date; self.reportID = reportID; self.source = source
    }
}
public struct Medication: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var name: String
    public var dose: String
    public var schedule: String
    public var startDate: Date
    public var endDate: Date?
    public var reportID: UUID?
    public var note: String
    public init(name: String, dose: String, schedule: String, startDate: Date, reportID: UUID? = nil, note: String = "") {
        self.name = name; self.dose = dose; self.schedule = schedule; self.startDate = startDate; self.reportID = reportID; self.note = note
    }
    public func isActive(on date: Date = Date()) -> Bool { startDate <= date && (endDate == nil || endDate! > date) }
}
public struct Report: Identifiable, Codable, Sendable {
    public var id: UUID
    public var title: String
    public var date: Date
    public var importedAt: Date
    public var filename: String
    public var digest: String
    public var text: String
    public init(id: UUID, title: String, date: Date, filename: String, digest: String, text: String) {
        self.id = id; self.title = title; self.date = date; self.importedAt = Date(); self.filename = filename; self.digest = digest; self.text = text
    }
}
public struct Visit: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var date: Date
    public var title: String
    public var notes: String
    public var completed = false
    public init(date: Date, title: String, notes: String) { self.date = date; self.title = title; self.notes = notes }
}
public struct Profile: Codable, Sendable {
    public var program = "Mein DMP"
    public var practice = ""
    public var goals = ""
    public init() {}
}
public struct HealthRecord: Codable, Sendable {
    public var version = 1
    public var profile = Profile()
    public var measurements: [Measurement] = []
    public var medications: [Medication] = []
    public var reports: [Report] = []
    public var visits: [Visit] = []
    public init() {}
}
public struct Finding: Identifiable, Sendable {
    public var id = UUID()
    public var metric: Metric
    public var value: Double
    public var unit: String
    public var source: String
}
public enum ReportParser {
    public static func number(_ text: String) -> Double? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(clean), value.isFinite, value > 0 else { return nil }
        return value
    }
    /// Conservative, line-based candidates. Units are mandatory; comparisons and reference lines are omitted.
    /// A candidate is never a confirmed measurement. Date and every selected value require user review.
    public static func findings(in text: String) -> [Finding] {
        let definitions: [(Metric, String, String)] = [
            (.hba1c, "HbA1c", "%|mmol/mol"), (.weight, "Gewicht|Körpergewicht", "kg"),
            (.ldl, "LDL(?:-Cholesterin)?", "mg/dl|mmol/l"),
            (.glucose, "Glukose|Glucose|Nüchternblutzucker", "mg/dl|mmol/l"), (.fev1, "FEV1", "l|%")
        ]
        var result: [Finding] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.contains("<"), !line.contains(">"), !line.contains("≤"), !line.contains("≥"),
                  line.range(of: "Referenz|Normwert|Zielwert|Zielbereich|Vorwert", options: [.regularExpression, .caseInsensitive]) == nil else { continue }
            for (metric, label, units) in definitions {
                let pattern = "(?i)^(?:\(label))\\s*[:=]?\\s*([0-9]+(?:[.,][0-9]+)?)\\s*(\(units))(?![a-z/])"
                if let groups = captures(pattern, line), let value = number(groups[0]),
                   let unit = metric.units.first(where: { $0.lowercased() == groups[1].lowercased() }) {
                    result.append(Finding(metric: metric, value: value, unit: unit, source: line))
                }
            }
            if let groups = captures("(?i)^(?:RR|Blutdruck)\\s*[:=]?\\s*([0-9]{2,3})\\s*/\\s*([0-9]{2,3})\\s*mmHg\\b", line),
               let sys = number(groups[0]), let dia = number(groups[1]) {
                result.append(Finding(metric: .systolic, value: sys, unit: "mmHg", source: line))
                result.append(Finding(metric: .diastolic, value: dia, unit: "mmHg", source: line))
            }
        }
        return result
    }
    private static func captures(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
    }
}

public struct MedicationFinding: Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var dose: String
    public var schedule: String
    public var source: String
}
extension ReportParser {
    /// Only explicit name + strength + 3/4-slot schedules are suggested. Never infer instructions.
    public static func medicationFindings(in text: String) -> [MedicationFinding] {
        let pattern = #"^([\p{L}][\p{L}0-9 ®.-]{1,60}?)\s+([0-9]+(?:[.,][0-9]+)?\s*(?:mg|µg|μg|mcg|g|I\.?E\.?))\s+([0-9]+(?:[.,][0-9]+)?\s*-\s*[0-9]+(?:[.,][0-9]+)?\s*-\s*[0-9]+(?:[.,][0-9]+)?(?:\s*-\s*[0-9]+(?:[.,][0-9]+)?)?)\s*$"#
        return text.components(separatedBy: .newlines).compactMap { line in
            guard let fields = captures(pattern, line.trimmingCharacters(in: .whitespaces)) else { return nil }
            return MedicationFinding(name: fields[0], dose: fields[1], schedule: fields[2], source: line)
        }
    }
}
