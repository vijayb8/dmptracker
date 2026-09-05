import XCTest
@testable import DMPCore
final class ReportParserTests: XCTestCase {
    func testGermanDecimalAndExplicitUnits() {
        let values = ReportParser.findings(in: "HbA1c: 6,7 %\nLDL 2,1 mmol/l\nGewicht: 81,2 kg")
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values[0].value, 6.7)
        XCTAssertEqual(values[1].unit, "mmol/l")
    }
    func testRejectsAmbiguousAndThresholdValues() {
        for text in ["HbA1c 48", "HbA1c < 7 %", "Zielwert HbA1c 7 %", "HbA1c: 7 % Referenz", "HbA1c 7 mmol/l", "LDL 100 mg/dl/min", "FEV1 80 l/min"] {
            XCTAssertTrue(ReportParser.findings(in: text).isEmpty, text)
        }
    }
    func testBloodPressureIsTwoSeparateMeasurements() {
        let values = ReportParser.findings(in: "RR: 128/82 mmHg")
        XCTAssertEqual(values.map(\.metric), [.systolic, .diastolic])
        XCTAssertEqual(values.map(\.value), [128, 82])
    }
    func testNoUnitConversionOrDateGuessing() {
        let values = ReportParser.findings(in: "HbA1c 48 mmol/mol\nHbA1c 6,5 %")
        XCTAssertEqual(values.map(\.unit), ["mmol/mol", "%"])
    }
    func testMedicationSuggestionsPreserveExplicitSchedule() {
        let items = ReportParser.medicationFindings(in: "Beispielmittel 500 mg 1-0-1\nUnklar 5 mg\nLDL 100 mg/dl")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.dose, "500 mg")
        XCTAssertEqual(items.first?.schedule, "1-0-1")
    }
    func testInvalidNumbers() {
        for text in ["nan", "inf", "-1", "0", "1,2,3", ""] { XCTAssertNil(ReportParser.number(text)) }
    }
    func testMedicationDateBoundariesAndRoundTrip() throws {
        let start = Date(timeIntervalSince1970: 100)
        var medication = Medication(name: "Synthetic example", dose: "As recorded", schedule: "As recorded", startDate: start)
        medication.endDate = Date(timeIntervalSince1970: 200)
        XCTAssertFalse(medication.isActive(on: Date(timeIntervalSince1970: 99)))
        XCTAssertTrue(medication.isActive(on: start))
        XCTAssertFalse(medication.isActive(on: medication.endDate!))
        var record = HealthRecord(); record.medications = [medication]
        let decoded = try JSONDecoder().decode(HealthRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(decoded.medications.first?.endDate, medication.endDate)
    }
}
