import SwiftUI

struct MedicationListView: View {
    @EnvironmentObject var store: HealthStore
    @State private var add = false
    @State private var edit: Medication?
    var body: some View {
        NavigationStack {
            List {
                Section { Text("Dein persönlich bestätigter Medikationsplan. Änderungen bitte mit der Praxis abstimmen.").font(.subheadline).foregroundStyle(.secondary) }
                if store.record.medications.isEmpty { ContentUnavailableView("Noch keine Medikamente", systemImage: "pills", description: Text("Trage Name, Dosis und Einnahme laut deinem Plan ein.")) }
                Section("Aktuell") { ForEach(store.record.medications.filter { $0.isActive() }) { row($0) } }
                Section("Verlauf / geplant") { ForEach(store.record.medications.filter { !$0.isActive() }) { row($0) } }
            }.navigationTitle("Medikamente")
                .toolbar { Button { add = true } label: { Label("Medikament hinzufügen", systemImage: "plus") } }
                .sheet(isPresented: $add) { MedicationEditor { item in store.change { $0.medications.append(item) } } }
                .sheet(item: $edit) { existing in MedicationEditor(existing: existing) { item in store.change { record in record.medications.removeAll { $0.id == item.id }; record.medications.append(item) } } }
        }
    }
    func row(_ item: Medication) -> some View {
        Button { edit = item } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name).font(.headline)
                Text("\(item.dose) · \(item.schedule)")
                Text("Seit \(item.startDate.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                if let end = item.endDate { Text("Beendet: \(end.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary) }
            }.foregroundStyle(.primary)
        }
    }
}
struct MedicationEditor: View {
    @EnvironmentObject var store: HealthStore
    @Environment(\.dismiss) var dismiss
    var existing: Medication?
    var seed: Medication?
    var save: (Medication) -> Bool
    @State private var name = ""
    @State private var dose = ""
    @State private var schedule = ""
    @State private var note = ""
    @State private var start = Date()
    @State private var ended = false
    @State private var end = Date()
    @State private var delete = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Laut ärztlichem Medikationsplan") {
                    TextField("Name", text: $name)
                    TextField("Dosis / Stärke", text: $dose)
                    TextField("Einnahme, z. B. morgens laut Plan", text: $schedule, axis: .vertical)
                    DatePicker("Beginn", selection: $start, displayedComponents: .date)
                    Toggle("Einnahme beendet", isOn: $ended)
                    if ended { DatePicker("Ende", selection: $end, in: start..., displayedComponents: .date) }
                    TextField("Notiz / Quelle", text: $note, axis: .vertical)
                }
                Section { Text("Bei einer Dosisänderung den bisherigen Eintrag beenden und einen neuen anlegen. So bleibt dein Verlauf erhalten.").font(.footnote) }
                if existing != nil { Button("Eintrag löschen", role: .destructive) { delete = true } }
            }.navigationTitle(existing == nil ? "Medikament hinzufügen" : "Medikament bearbeiten")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") {
                        var item = Medication(name: name.trimmingCharacters(in: .whitespacesAndNewlines), dose: dose, schedule: schedule, startDate: start, reportID: existing?.reportID, note: note)
                        if let existing { item.id = existing.id }; item.endDate = ended ? end : nil
                        if save(item) { dismiss() }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || schedule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (ended && end < start)) }
                }.onAppear { if let item = existing ?? seed { name = item.name; dose = item.dose; schedule = item.schedule; start = item.startDate; note = item.note; ended = item.endDate != nil; end = item.endDate ?? Date() } }
                .confirmationDialog("Medikament aus dem Verlauf löschen?", isPresented: $delete) {
                    Button("Löschen", role: .destructive) { if let item = existing, store.change({ $0.medications.removeAll { $0.id == item.id } }) { dismiss() } }
                }
        }
    }
}
