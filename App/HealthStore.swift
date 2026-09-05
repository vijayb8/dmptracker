import SwiftUI
import LocalAuthentication

@MainActor final class HealthStore: ObservableObject {
    @Published private(set) var record = HealthRecord()
    @Published var error: String?
    @Published private(set) var ready = false
    @Published private(set) var unlocked = false
    private var authenticating = false
    private var lockGeneration = 0
    private let root: URL
    init() {
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PersonalHealth", isDirectory: true)
    }
    func unlock() async {
        guard !authenticating else { return }
        authenticating = true
        let generation = lockGeneration
        defer { authenticating = false }
        do {
            let context = LAContext()
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Deine persönlichen Gesundheitsdaten öffnen")
            guard success, generation == lockGeneration else { return }
            try prepareDirectory()
            let file = root.appendingPathComponent("record.json")
            if FileManager.default.fileExists(atPath: file.path) {
                let decoded = try JSONDecoder().decode(HealthRecord.self, from: Data(contentsOf: file))
                guard decoded.version == 1 else { throw AppError.message("Diese Datenversion wird nicht unterstützt.") }
                record = decoded
            }
            ready = true; unlocked = true
            try? FileManager.default.removeItem(at: root.appendingPathComponent("Export"))
        } catch { self.error = "Öffnen fehlgeschlagen. Bitte Gerätecode einrichten bzw. erneut versuchen. Bestehende Daten werden nicht überschrieben.\n\(error.localizedDescription)" }
    }
    func lock() { lockGeneration += 1; unlocked = false }
    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        try protect(root)
    }
    private func protect(_ url: URL) throws {
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        var mutable = url; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try mutable.setResourceValues(values)
    }
    @discardableResult func change(_ edit: (inout HealthRecord) -> Void) -> Bool {
        guard ready, unlocked else { error = "Bitte zuerst entsperren."; return false }
        var next = record; edit(&next)
        do {
            let data = try JSONEncoder().encode(next)
            let url = root.appendingPathComponent("record.json")
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            try protect(url)
            record = next
            return true
        } catch { self.error = "Speichern fehlgeschlagen: \(error.localizedDescription)"; return false }
    }
    func reportURL(_ report: Report) -> URL { root.appendingPathComponent(report.filename) }
    func saveImport(_ draft: ImportDraft, title: String, date: Date, values: [Measurement], medications: [Medication]) -> Bool {
        guard unlocked, ready else { return false }
        guard !record.reports.contains(where: { $0.digest == draft.digest }) else { error = "Dieser Bericht wurde bereits importiert."; return false }
        let id = UUID(); let filename = "\(id.uuidString).pdf"
        let url = root.appendingPathComponent(filename)
        do {
            try draft.pdf.write(to: url, options: [.atomic, .completeFileProtection]); try protect(url)
            let report = Report(id: id, title: title, date: date, filename: filename, digest: draft.digest, text: draft.text)
            let saved = change { record in
                record.reports.append(report)
                record.measurements += values.map { var value = $0; value.reportID = id; return value }
                record.medications += medications.map { var medication = $0; medication.reportID = id; return medication }
            }
            if !saved { try? FileManager.default.removeItem(at: url) }
            return saved
        } catch { self.error = error.localizedDescription; try? FileManager.default.removeItem(at: url); return false }
    }
    func deleteReport(_ report: Report) {
        // Delete the document before dropping its reference so a failed deletion remains retryable.
        do {
            let url = reportURL(report)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            change { record in
                record.reports.removeAll { $0.id == report.id }
                record.measurements.removeAll { $0.reportID == report.id }
                record.medications.removeAll { $0.reportID == report.id }
            }
        } catch { self.error = error.localizedDescription }
    }
    func exportURL() throws -> URL {
        let directory = root.appendingPathComponent("Export", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        try protect(directory)
        let url = directory.appendingPathComponent("Meine-DMP-Uebersicht.pdf")
        try SummaryPDF.make(record).write(to: url, options: [.atomic, .completeFileProtection])
        try protect(url)
        return url
    }
    func clearExport(_ url: URL) { try? FileManager.default.removeItem(at: url) }
    func erase() {
        guard unlocked else { return }
        do {
            if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
            record = HealthRecord(); try prepareDirectory()
        } catch { self.error = "Löschen nicht vollständig: \(error.localizedDescription)" }
    }
}
enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
