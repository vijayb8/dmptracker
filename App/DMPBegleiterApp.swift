import SwiftUI

@main struct DMPBegleiterApp: App {
    @StateObject private var store = HealthStore()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            ZStack {
                if store.unlocked {
                    RootView().environmentObject(store)
                } else {
                    VStack(spacing: 24) {
                        Image(systemName: "heart.text.clipboard.fill").font(.system(size: 64)).foregroundStyle(.teal)
                        Text("DMP Begleiter").font(.largeTitle.bold())
                        Text("Dein DMP. Dein Überblick.").font(.title3).foregroundStyle(.secondary)
                        Text("Berichte, Medikamente und Verlauf – auf deinem iPhone.").multilineTextAlignment(.center)
                        Button("Mit Face ID / Gerätecode öffnen") { Task { await store.unlock() } }.buttonStyle(.borderedProminent).tint(.teal)
                        Text("Ein Gerätecode ist erforderlich.").font(.footnote).foregroundStyle(.secondary)
                    }.padding(32)
                }
                if phase != .active {
                    Color(.systemBackground).ignoresSafeArea()
                    Label("DMP Begleiter", systemImage: "lock.shield.fill").font(.title2)
                }
            }
            .tint(.teal)
            .environment(\.locale, Locale(identifier: "de_DE"))
            .onChange(of: phase) { _, next in if next == .background { store.lock() } }
            .alert("Hinweis", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
        }
    }
}
struct RootView: View {
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Übersicht", systemImage: "square.grid.2x2") }
            MedicationListView().tabItem { Label("Medikamente", systemImage: "pills") }
            ReportsView().tabItem { Label("Berichte", systemImage: "doc.text") }
            VisitsView().tabItem { Label("Termine", systemImage: "calendar") }
            SettingsView().tabItem { Label("Mein DMP", systemImage: "person.crop.circle") }
        }
    }
}
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 12) { content }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22)) }
}
