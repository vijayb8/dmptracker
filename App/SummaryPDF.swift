import UIKit

enum SummaryPDF {
    static func make(_ record: HealthRecord) -> Data {
        let date = { (value: Date) in value.formatted(date: .abbreviated, time: .omitted) }
        var lines: [String] = ["DMP Begleiter · Persönliche Übersicht", "Erstellt: \(date(Date()))", "Programm: \(record.profile.program)", "Praxis: \(record.profile.practice)", "Persönlich erfasst; keine ärztlich validierte Dokumentation.", "", "VEREINBARTE ZIELE", record.profile.goals, "", "MEDIKAMENTE"]
        for item in record.medications.sorted(by: { $0.startDate < $1.startDate }) {
            let status = item.isActive() ? "Aktuell" : "Beendet / geplant"
            lines += ["\(item.name) · \(item.dose)", "\(item.schedule) · \(status)", "Beginn: \(date(item.startDate)) · Ende: \(item.endDate.map(date) ?? "offen")", item.note, ""]
        }
        lines += ["MESSWERTE"]
        for item in record.measurements.sorted(by: { $0.date > $1.date }) {
            lines += ["\(date(item.date)) · \(item.metric.title): \(item.value.formatted()) \(item.unit)", "Quelle: \(item.source)"]
        }
        lines += ["", "TERMINE UND NOTIZEN"]
        for item in record.visits.sorted(by: { $0.date < $1.date }) {
            lines += ["\(item.date.formatted(date: .abbreviated, time: .shortened)) · \(item.title) · \(item.completed ? "erledigt" : "offen")", item.notes, ""]
        }
        lines += ["BERICHTSVERZEICHNIS"]
        for item in record.reports.sorted(by: { $0.date > $1.date }) { lines += ["\(date(item.date)) · \(item.title)"] }
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: "Persönliche DMP-Übersicht"]
        return UIGraphicsPDFRenderer(bounds: bounds, format: format).pdfData { context in
            let style = NSMutableParagraphStyle(); style.lineSpacing = 4
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.black, .paragraphStyle: style]
            var page = 0; var y: CGFloat = 48
            func beginPage() {
                context.beginPage(); page += 1; y = 48
                ("DMP Begleiter · Persönlich · Seite \(page)" as NSString).draw(at: CGPoint(x: 44, y: 806), withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.darkGray])
            }
            beginPage()
            // TextKit lays out into page-sized containers, including arbitrarily long notes.
            let text = NSAttributedString(string: lines.joined(separator: "\n"), attributes: attributes)
            let storage = NSTextStorage(attributedString: text)
            let layout = NSLayoutManager(); storage.addLayoutManager(layout)
            var laidOut = 0
            repeat {
                let container = NSTextContainer(size: CGSize(width: 507, height: 740)); container.lineFragmentPadding = 0
                layout.addTextContainer(container)
                let range = layout.glyphRange(for: container)
                if range.length == 0 { break }
                if laidOut > 0 { beginPage() }
                layout.drawBackground(forGlyphRange: range, at: CGPoint(x: 44, y: y))
                layout.drawGlyphs(forGlyphRange: range, at: CGPoint(x: 44, y: y))
                laidOut = NSMaxRange(range)
            } while laidOut < layout.numberOfGlyphs
        }
    }
}
