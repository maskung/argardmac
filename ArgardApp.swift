import SwiftUI

@main
struct ArgardApp: App {
    @StateObject private var store = WeatherStore()

    var body: some Scene {
        WindowGroup("Argard — Personal Weather Station") {
            ContentView(store: store)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}   // ซ่อนเมนู File > New
            CommandMenu("Weather") {
                Button("Refresh Now") {
                    Task { await store.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Dashboard") { store.tab = .dashboard }
                    .keyboardShortcut("1", modifiers: .command)
                Button("12h Forecast") { store.tab = .forecast }
                    .keyboardShortcut("2", modifiers: .command)
            }
        }
    }
}
