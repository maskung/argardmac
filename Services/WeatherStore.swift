import Foundation
import SwiftUI

/// State กลางของแอพ — เก็บข้อมูลที่ดึงมา + error + เวลาอัปเดตล่าสุด
/// และคุม auto-refresh ตาม REFRESH_SECONDS
@MainActor
final class WeatherStore: ObservableObject {
    enum Tab: Hashable { case dashboard, forecast }

    @Published var obs = PWSObservation()
    @Published var forecast: [OWForecastItem] = []
    @Published var air = AQCurrent()
    @Published var errorMessage = ""
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var tab: Tab = .dashboard

    let config: AppConfig
    private let service: WeatherService
    private var refreshTask: Task<Void, Never>?

    init(config: AppConfig = AppConfig.load()) {
        self.config = config
        self.service = WeatherService(config: config)
    }

    var refreshSeconds: Int { max(10, config.refreshSeconds) }

    /// ดึงข้อมูลใหม่ทั้ง 3 แหล่งพร้อมกัน
    func refresh() async {
        isLoading = true
        defer {
            isLoading = false
            lastUpdated = Date()
        }

        async let obsResult = service.fetchObservation()
        async let forecastResult = service.fetchForecast()
        async let airResult = service.fetchAirQuality()

        let (o, f, a) = await (obsResult, forecastResult, airResult)
        obs = o.0
        forecast = f.0
        air = a.0

        // รวม error แบบเดียวกับ Python: obs มาก่อน แล้ว forecast แล้ว aqi
        let errors = [o.1, f.1, a.1].filter { !$0.isEmpty }
        errorMessage = errors.joined(separator: " • ")
    }

    /// เริ่ม auto-refresh loop (เรียกจาก .task ของ view)
    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.refreshSeconds))
                guard !Task.isCancelled else { break }
                await self.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
