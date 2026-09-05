import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var store: HealthStore
    @State private var add = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(store.record.profile.program).font(.subheadline.weight(.semibold)).foregroundStyle(.teal)
                    Text("Deine Gesundheit\nim Blick.").font(.largeTitle.bold())
                    Text("Ein Schritt nach dem anderen.").foregroundStyle(.secondary)
                    if let visit = store.record.visits.filter({ !$0.completed }).sorted(by: { $0.date < $1.date }).first {
                        Panel {
                            Label(visit.date < Date() ? "Termin prüfen" : "Nächster Termin", systemImage: "calendar").foregroundStyle(.teal)
                            Text(visit.title).font(.headline)
                            Text(visit.date.formatted(date: .abbreviated, time: .shortened))
                            if !store.record.profile.practice.isEmpty { Text(store.record.profile.practice).foregroundStyle(.secondary) }
                        }
                    }
                    HStack(spacing: 12) {
                        Panel { Text("\(store.record.medications.filter { $0.isActive() }.count)").font(.largeTitle.bold()); Text("Aktive Medikamente").font(.caption) }
                        Panel { Text("\(store.record.reports.count)").font(.largeTitle.bold()); Text("Gespeicherte Berichte").font(.caption) }
                    }
                    if store.record.measurements.isEmpty {
                        Panel {
                            Label("Dein Verlauf beginnt hier", systemImage: "chart.xyaxis.line").font(.headline)
                            Text("Importiere deinen ersten Bericht unter Berichte oder erfasse einen Messwert.").foregroundStyle(.secondary)
                            Button("Messwert erfassen") { add = true }.buttonStyle(.borderedProminent)
                        }
                    }
                    ForEach(Metric.allCases) { metric in
                        ForEach(metric.units, id: \.self) { unit in
                            let values = store.record.measurements.filter { $0.metric == metric && $0.unit == unit }.sorted { $0.date < $1.date }
                            if let latest = values.last {
                                NavigationLink { MeasurementHistory(metric: metric, unit: unit) } label: {
                                    Panel {
                                        Text(metric.title).font(.headline)
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(latest.value.formatted(.number.precision(.fractionLength(0...2)))).font(.system(.largeTitle, design: .rounded).bold())
                                            Text(unit).foregroundStyle(.secondary)
                                            Spacer()
                                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                        }
                                        if values.count > 1 {
                                            Chart(values) { item in
                                                LineMark(x: .value("Datum", item.date), y: .value(unit, item.value))
                                                PointMark(x: .value("Datum", item.date), y: .value(unit, item.value))
                                            }.foregroundStyle(.teal).frame(height: 110).chartYScale(domain: .automatic(includesZero: false))
                                        }
                                        Text("Zuletzt: \(latest.date.formatted(date: .abbreviated, time: .omitted)) · \(values.count) Messwerte").font(.caption).foregroundStyle(.secondary)
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if !store.record.profile.goals.isEmpty {
                        Panel { Label("Mit der Praxis vereinbart", systemImage: "target").font(.headline); Text(store.record.profile.goals) }
                    }
                    Text("Persönliches Tagebuch. Messwerte beschreiben deinen Verlauf und ersetzen keine ärztliche Beurteilung.").font(.footnote).foregroundStyle(.secondary)
                }.padding(20)
            }.background(Color(.systemGroupedBackground)).navigationTitle("Übersicht").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button { add = true } label: { Label("Messwert hinzufügen", systemImage: "plus") } }
                .sheet(isPresented: $add) { MeasurementEditor() }
        }
    }
}
struct MeasurementHistory: View {
    @EnvironmentObject var store: HealthStore
    let metric: Metric
    let unit: String
    @State private var edit: Measurement?
    var values: [Measurement] { store.record.measurements.filter { $0.metric == metric && $0.unit == unit }.sorted { $0.date > $1.date } }
    var body: some View {
        List {
            ForEach(values) { item in
                Button { edit = item } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(item.value.formatted()) \(item.unit)").font(.headline)
                        Text(item.date.formatted(date: .abbreviated, time: .omitted))
                        Text(item.source).font(.caption).foregroundStyle(.secondary)
                    }.foregroundStyle(.primary)
                }
            }.onDelete { offsets in
                let ids = offsets.map { values[$0].id }; store.change { $0.measurements.removeAll { ids.contains($0.id) } }
            }
        }.navigationTitle(metric.title).sheet(item: $edit) { MeasurementEditor(existing: $0) }
    }
}
struct MeasurementEditor: View {
    @EnvironmentObject var store: HealthStore
    @Environment(\.dismiss) var dismiss
    var existing: Measurement?
    @State private var metric: Metric = .weight
    @State private var value = ""
    @State private var unit = "kg"
    @State private var date = Date()
    @State private var source = "Manuell erfasst"
    var body: some View {
        NavigationStack {
            Form {
                Picker("Messwert", selection: $metric) { ForEach(Metric.allCases) { Text($0.title).tag($0) } }
                    .onChange(of: metric) { _, next in if !next.units.contains(unit) { unit = next.units[0] } }
                TextField("Wert", text: $value).keyboardType(.decimalPad)
                Picker("Einheit", selection: $unit) { ForEach(metric.units, id: \.self) { Text($0).tag($0) } }
                DatePicker("Messdatum", selection: $date, in: ...Date(), displayedComponents: .date)
                TextField("Quelle / Notiz", text: $source, axis: .vertical)
            }.navigationTitle(existing == nil ? "Messwert erfassen" : "Messwert korrigieren")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") {
                        guard let number = ReportParser.number(value) else { return }
                        var item = Measurement(metric: metric, value: number, unit: unit, date: date, reportID: existing?.reportID, source: source)
                        if let existing { item.id = existing.id }
                        if store.change({ record in record.measurements.removeAll { $0.id == item.id }; record.measurements.append(item) }) { dismiss() }
                    }.disabled(ReportParser.number(value) == nil || !metric.units.contains(unit)) }
                }.onAppear {
                    if let item = existing { metric = item.metric; value = String(item.value); unit = item.unit; date = item.date; source = item.source }
                }
        }
    }
}
