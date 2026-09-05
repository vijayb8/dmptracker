import SwiftUI

struct VisitsView: View {
    @EnvironmentObject var store: HealthStore
    @State private var add = false
    @State private var edit: Visit?
    var sorted: [Visit] { store.record.visits.sorted { $0.date < $1.date } }
    var body: some View {
        NavigationStack {
            List {
                if sorted.isEmpty { ContentUnavailableView("Dein nächster DMP-Termin", systemImage: "calendar.badge.plus", description: Text("Erfasse den mit deiner Hausarztpraxis vereinbarten Termin und deine Fragen.")) }
                ForEach(sorted) { visit in
                    Button { edit = visit } label: {
                        HStack {
                            Image(systemName: visit.completed ? "checkmark.circle.fill" : "calendar").foregroundStyle(.teal)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(visit.title).font(.headline)
                                Text(visit.date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline)
                                if !visit.notes.isEmpty { Text(visit.notes).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
                                if visit.completed { Text("Erledigt").font(.caption).foregroundStyle(.teal) }
                            }.foregroundStyle(.primary)
                        }
                    }
                }.onDelete { offsets in let ids = offsets.map { sorted[$0].id }; store.change { $0.visits.removeAll { ids.contains($0.id) } } }
            }.navigationTitle("Hausarzt-Termine")
                .toolbar { Button { add = true } label: { Label("Termin hinzufügen", systemImage: "plus") } }
                .sheet(isPresented: $add) { VisitEditor() }
                .sheet(item: $edit) { VisitEditor(existing: $0) }
        }
    }
}
struct VisitEditor: View {
    @EnvironmentObject var store: HealthStore
    @Environment(\.dismiss) var dismiss
    var existing: Visit?
    @State private var title = "DMP-Kontrolle"
    @State private var date = Date()
    @State private var notes = ""
    @State private var completed = false
    var body: some View {
        NavigationStack {
            Form {
                TextField("Termin", text: $title)
                DatePicker("Datum und Uhrzeit", selection: $date)
                TextField("Fragen, Untersuchungen, nächste Schritte", text: $notes, axis: .vertical).lineLimit(4...12)
                Toggle("Termin erledigt", isOn: $completed)
                Text("Trage den tatsächlich vereinbarten Termin ein. Die App legt keine medizinischen Kontrollintervalle fest und sendet derzeit keine Erinnerungen.").font(.caption).foregroundStyle(.secondary)
            }.navigationTitle("DMP-Termin")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") {
                        var item = Visit(date: date, title: title, notes: notes); item.completed = completed
                        if let existing { item.id = existing.id }
                        if store.change({ record in record.visits.removeAll { $0.id == item.id }; record.visits.append(item) }) { dismiss() }
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }.onAppear { if let item = existing { title = item.title; date = item.date; notes = item.notes; completed = item.completed } }
        }
    }
}
struct ExportItem: Identifiable { let id = UUID(); let url: URL }
struct SettingsView: View {
    @EnvironmentObject var store: HealthStore
    @State private var profile = Profile()
    @State private var erase = false
    @State private var export: ExportItem?
    @State private var exportedURL: URL?
    @State private var saved = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Mein Programm") {
                    TextField("DMP, z. B. Diabetes Typ 2", text: $profile.program)
                    TextField("Hausarztpraxis", text: $profile.practice)
                    TextField("Vereinbarte Ziele und nächste Schritte", text: $profile.goals, axis: .vertical).lineLimit(3...10)
                    Button(saved ? "Gespeichert" : "Angaben speichern") { saved = store.change { $0.profile = profile } }
                }
                Section("Für deinen nächsten Arztbesuch") {
                    Button { do { let url = try store.exportURL(); exportedURL = url; export = ExportItem(url: url) } catch { store.error = error.localizedDescription } } label: { Label("PDF-Übersicht teilen", systemImage: "square.and.arrow.up") }
                    Text("Die Übersicht enthält deine Messwerte, Medikamente, Ziele und Termine. Teile sie nur mit den gewünschten Empfängern. Geteilte Kopien liegen außerhalb der App.").font(.caption)
                }
                Section("Deine Daten") {
                    Label("Kein Konto, kein Analyse-Tracking", systemImage: "person.crop.circle.badge.checkmark")
                    Label("Texterkennung auf dem Gerät", systemImage: "iphone")
                    Label("Geschützt durch Gerätecode / Face ID", systemImage: "lock.shield")
                    Text("Die App nutzt keinen Server und keine iCloud-Synchronisierung. Gesundheitsdateien sind mit vollständigem iOS-Dateischutz gespeichert und für den Ausschluss von Backups markiert. Diese Markierung ist keine absolute Backup-Garantie. Fotos bleiben gegebenenfalls in deiner Fotomediathek und deren Cloud-Synchronisierung.").font(.caption)
                    Text("Bei Geräteverlust oder Deinstallation können deine Daten verloren gehen. Die PDF-Übersicht dient zur Weitergabe; sie ist kein wiederherstellbares App-Backup.").font(.caption)
                    Button("App sperren") { store.lock() }
                    Button("Alle App-Daten löschen", role: .destructive) { erase = true }
                }
                Section("Über DMP Begleiter") {
                    Text("Persönliches Gesundheits-Tagebuch. Keine Verbindung zur Krankenkasse, ePA oder Praxis. Keine Diagnose, Therapieempfehlung oder automatische Dosisänderung.").font(.caption)
                    Text("Version 0.1 · Persönlicher Prototyp").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Mein DMP")
                .onAppear { profile = store.record.profile }
                .onChange(of: profile.program) { _, _ in saved = false }
                .onChange(of: profile.practice) { _, _ in saved = false }
                .onChange(of: profile.goals) { _, _ in saved = false }
                .sheet(item: $export, onDismiss: { if let url = exportedURL { store.clearExport(url) }; exportedURL = nil }) { ShareSheet(url: $0.url) }
                .confirmationDialog("Alle Berichte, Messwerte, Medikamente und Termine dauerhaft löschen?", isPresented: $erase) {
                    Button("Alle App-Daten löschen", role: .destructive) { store.erase(); profile = store.record.profile }
                }
        }
    }
}
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
