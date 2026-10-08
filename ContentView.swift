import SwiftUI

struct ContentView: View {
    @ObservedObject var store: WeatherStore

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(store: store)
            Divider()
            Group {
                switch store.tab {
                case .dashboard: DashboardView(store: store)
                case .forecast: ForecastView(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 980, minHeight: 680)
        .task {
            await store.refresh()
            store.startAutoRefresh()
        }
    }
}
