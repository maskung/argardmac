import SwiftUI

struct ContentView: View {
    @ObservedObject var store: WeatherStore

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            VStack(spacing: 0) {
                HeaderBar(store: store)
                Group {
                    switch store.tab {
                    case .dashboard: DashboardView(store: store)
                    case .forecast: ForecastView(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // ล็อคธีมเข้มให้เข้ากับดีไซน์หรูหรา
        .preferredColorScheme(.dark)
        .frame(minWidth: 1000, minHeight: 720)
        .task {
            await store.refresh()
            store.startAutoRefresh()
        }
    }
}
