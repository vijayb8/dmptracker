import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import VisionKit

struct ReportsView: View {
    @EnvironmentObject var store: HealthStore
    @State private var picker = false
    @State private var camera = false
    @State private var photo: PhotosPickerItem?
    @State private var draft: ImportDraft?
    @State private var busy = false
    @State private var delete: Report?
    @State private var query = ""
    var reports: [Report] { store.record.reports.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.text.localizedCaseInsensitiveContains(query) }.sorted { $0.date > $1.date } }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { camera = true } label: { Label("Bericht scannen", systemImage: "camera.viewfinder") }.disabled(!VNDocumentCameraViewController.isSupported || busy)
                    PhotosPicker(selection: $photo, matching: .images) { Label("Foto auswählen", systemImage: "photo") }.disabled(busy)
                    Button { picker = true } label: { Label("PDF oder Bild importieren", systemImage: "doc.badge.plus") }.disabled(busy)
                    Text("Erkennung auf deinem iPhone. Danach prüfst du die Angaben. Max. 25 MB und 30 Seiten.").font(.caption).foregroundStyle(.secondary)
                    if busy { ProgressView("Bericht wird gelesen …") }
                }
                if reports.isEmpty { ContentUnavailableView("Deine Berichte", systemImage: "doc.text.magnifyingglass", description: Text("Importierte Originale und bestätigte Werte findest du hier.")) }
                ForEach(reports) { report in
                    NavigationLink { ReportDetail(report: report) } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 5) { Text(report.title).font(.headline); Text(report.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary) }
                        } icon: { Image(systemName: "doc.richtext").foregroundStyle(.teal) }
                    }.swipeActions { Button("Löschen", role: .destructive) { delete = report } }
                }
            }.navigationTitle("Berichte").searchable(text: $query, prompt: "Berichte durchsuchen")
                .fileImporter(isPresented: $picker, allowedContentTypes: [.pdf, .image]) { result in
                    switch result {
                    case .success(let url): run { try DocumentService.load(url) }
                    case .failure(let error): store.error = error.localizedDescription
                    }
                }
                .onChange(of: photo) { _, selected in
                    guard let selected else { return }
                    busy = true
                    Task {
                        do {
                            guard let data = try await selected.loadTransferable(type: Data.self) else { throw AppError.message("Foto konnte nicht geladen werden.") }
                            await process(data)
                        } catch { store.error = error.localizedDescription; busy = false }
                        photo = nil
                    }
                }
                .sheet(isPresented: $camera) { DocumentScanner { result in
                    camera = false
                    switch result { case .success(let data): if let data { run { data } }; case .failure(let error): store.error = error.localizedDescription }
                } }
                .sheet(item: $draft) { ImportReview(draft: $0) }
                .confirmationDialog("Bericht sowie die daraus übernommenen Messwerte und Medikamente löschen?", isPresented: Binding(get: { delete != nil }, set: { if !$0 { delete = nil } })) {
                    Button("Bericht und zugehörige Einträge löschen", role: .destructive) { if let report = delete { store.deleteReport(report) }; delete = nil }
                }
        }
    }
    private func run(_ load: @escaping @Sendable () throws -> Data) {
        guard !busy else { return }; busy = true
        Task {
            do { let data = try await Task.detached(priority: .userInitiated) { try load() }.value; await process(data) }
            catch { store.error = error.localizedDescription; busy = false }
        }
    }
    @MainActor private func process(_ data: Data) async {
        defer { busy = false }
        do {
            let result = try await Task.detached(priority: .userInitiated) { try DocumentService.process(data) }.value
            guard store.unlocked else { return }
            guard !store.record.reports.contains(where: { $0.digest == result.digest }) else { throw AppError.message("Dieser Bericht ist bereits vorhanden.") }
            draft = result
        } catch { store.error = error.localizedDescription }
    }
}
struct ReviewValue: Identifiable {
    let id = UUID()
    var selected = false
    let finding: Finding
    var value: String
    var unit: String
}
struct ImportReview: View {
    @EnvironmentObject var store: HealthStore
    @Environment(\.dismiss) var dismiss
    let draft: ImportDraft
    @State private var title = "DMP-Bericht"
    @State private var date = Date()
    @State private var confirmed = false
    @State private var values: [ReviewValue] = []
    @State private var medications: [Medication] = []
    @State private var addMedication = false
    @State private var proposedMedication: Medication?
    @State private var manual = false
    @State private var manualMetric: Metric = .weight
    @State private var manualValue = ""
    @State private var manualUnit = "kg"
    @State private var preview = false
    @State private var initialized = false
    var valid: Bool { confirmed && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && values.filter(\.selected).allSatisfy { ReportParser.number($0.value) != nil } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Original prüfen") {
                    Button { preview = true } label: { Label("Bericht ansehen", systemImage: "doc.viewfinder") }
                    TextField("Titel", text: $title)
                    DatePicker("Mess- / Berichtsdatum", selection: $date, in: ...Date(), displayedComponents: .date)
                    Text("Datum im Original prüfen. Bei mehreren Messdaten nur Werte dieses Datums übernehmen; weitere Werte anschließend manuell mit ihrem Datum erfassen.").font(.caption)
                    ForEach(draft.warnings, id: \.self) { Text($0).foregroundStyle(.orange) }
                }
                Section("Erkannte Messwerte · einzeln auswählen") {
                    if values.isEmpty { Text("Keine eindeutigen Messwerte erkannt. Du kannst Werte manuell ergänzen und das Original trotzdem speichern.") }
                    ForEach($values) { $item in
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(item.finding.metric.title, isOn: $item.selected)
                            HStack { TextField("Wert", text: $item.value).keyboardType(.decimalPad); Picker("Einheit", selection: $item.unit) { ForEach(item.finding.metric.units, id: \.self) { Text($0).tag($0) } } }
                            Text(item.finding.source).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    DisclosureGroup("Messwert manuell ergänzen", isExpanded: $manual) {
                        Picker("Messwert", selection: $manualMetric) { ForEach(Metric.allCases) { Text($0.title).tag($0) } }.onChange(of: manualMetric) { _, next in manualUnit = next.units[0] }
                        TextField("Wert", text: $manualValue).keyboardType(.decimalPad)
                        Picker("Einheit", selection: $manualUnit) { ForEach(manualMetric.units, id: \.self) { Text($0).tag($0) } }
                        Button("Zur Prüfung hinzufügen") {
                            if let number = ReportParser.number(manualValue) {
                                let finding = Finding(metric: manualMetric, value: number, unit: manualUnit, source: "Manuell aus Bericht übertragen")
                                values.append(ReviewValue(finding: finding, value: manualValue, unit: manualUnit)); manualValue = ""
                            }
                        }.disabled(ReportParser.number(manualValue) == nil)
                    }
                }
                Section("Medikamente aus diesem Bericht") {
                    Text("Name, Dosis, Beginn und Einnahme anhand des Originalplans übernehmen. Vorhandene Medikamente werden nicht automatisch ersetzt.").font(.caption)
                    ForEach(ReportParser.medicationFindings(in: draft.text)) { suggestion in
                        Button {
                            proposedMedication = Medication(name: suggestion.name, dose: suggestion.dose, schedule: suggestion.schedule, startDate: date, note: suggestion.source)
                        } label: { VStack(alignment: .leading) { Text("Vorschlag prüfen: " + suggestion.name); Text(suggestion.source).font(.caption).foregroundStyle(.secondary) } }
                    }
                    ForEach(medications) { item in VStack(alignment: .leading) { Text(item.name).font(.headline); Text("\(item.dose) · \(item.schedule)") } }.onDelete { medications.remove(atOffsets: $0) }
                    Button("Medikament aus Bericht übernehmen") { addMedication = true }
                }
                Section("Erkannter Text") { DisclosureGroup("Text anzeigen / kopieren") { Text(draft.text.isEmpty ? "Kein Text erkannt" : draft.text).font(.caption).textSelection(.enabled) } }
                Section {
                    Toggle("Original, Datum, Einheiten und ausgewählte Angaben geprüft", isOn: $confirmed)
                    Text("Nur ausgewählte Messwerte und hinzugefügte Medikamente aktualisieren deine Übersicht.").font(.caption)
                }
            }.navigationTitle("Import prüfen").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Übernehmen") {
                        let selected = values.filter(\.selected).compactMap { item -> Measurement? in
                            guard let number = ReportParser.number(item.value) else { return nil }
                            return Measurement(metric: item.finding.metric, value: number, unit: item.unit, date: date, source: item.finding.source)
                        }
                        if store.saveImport(draft, title: title, date: date, values: selected, medications: medications) { dismiss() }
                    }.disabled(!valid) }
                }
                .onAppear { guard !initialized else { return }; initialized = true; values = draft.findings.map { ReviewValue(finding: $0, value: String($0.value), unit: $0.unit) } }
                .sheet(isPresented: $preview) { NavigationStack { PDFPreview(data: draft.pdf).navigationTitle("Original").toolbar { Button("Fertig") { preview = false } } } }
                .sheet(isPresented: $addMedication) { MedicationEditor { item in medications.append(item); return true } }
                .sheet(item: $proposedMedication) { item in MedicationEditor(seed: item) { reviewed in medications.append(reviewed); return true } }
                .interactiveDismissDisabled()
        }
    }
}
struct ReportDetail: View {
    @EnvironmentObject var store: HealthStore
    let report: Report
    @State private var data: Data?
    @State private var error: String?
    var body: some View {
        Group {
            if let data { PDFPreview(data: data) }
            else if let error { ContentUnavailableView("Bericht nicht verfügbar", systemImage: "doc.badge.ellipsis", description: Text(error)) }
            else { ProgressView() }
        }.navigationTitle(report.title).navigationBarTitleDisplayMode(.inline)
            .task { do { data = try Data(contentsOf: store.reportURL(report)) } catch { self.error = error.localizedDescription } }
    }
}
