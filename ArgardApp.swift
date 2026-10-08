import SwiftUI

/// ข้อมูลเวอร์ชั่นของแอพ (แก้ที่เดียว — อย่าลืมแก้ Info.plist ให้ตรงกันตอน bump)
enum AppInfo {
    static let version = "1.1.3"
    static let copyright = "Copyright © 2026 Suphanut Thanyaboon (suphanut@gmail.com)"
}

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
