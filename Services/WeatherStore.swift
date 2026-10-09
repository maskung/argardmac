import Foundation
import SwiftUI
import AppKit
import os

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
    private let logger = Logger(subsystem: "th.suphanutthanyaboon.argard", category: "store")
    private var refreshCount = 0

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
        if errors.isEmpty {
            // log ค่าจริงที่ได้รับ + เลขกำกับรอบ (กันข้อความซ้ำถูกยุบโดย unified log)
            refreshCount += 1
            logger.log("""
                refresh#\(self.refreshCount) สำเร็จ obs=\(self.obs.obsTimeLocal, privacy: .public) \
                temp=\(self.obs.metric.temp ?? -999, privacy: .public) \
                rh=\(self.obs.humidity ?? -999, privacy: .public) \
                dir=\(self.obs.winddir ?? -999, privacy: .public) \
                press=\(self.obs.metric.pressure ?? -999, privacy: .public) \
                uv=\(self.obs.uv ?? -999, privacy: .public)
                """)
        } else {
            logger.error("refresh มี error: \(self.errorMessage, privacy: .public)")
        }
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

    /// ดึงข้อมูลใหม่ทันทีทุกครั้งที่แอพกลับมา active หรือ Mac ตื่นจาก sleep
    /// — รับประกันว่าพอผู้ใช้กลับมาดูแอพจะได้ข้อมูลสดเสมอ แม้ timer จะถูกพักไปนาน
    ///
    /// และหยุดดึง API เมื่อหน้าจอ/ฝาปิด (ประหยัดโควต้ารายวัน):
    /// - หน้าจอ sleep (ปิดฝา/จอดับ) → หยุด loop ทั้งหมด ไม่ยิง API แม้เครื่องยังไม่หลับ
    /// - หน้าจอตื่น / Mac ตื่น → refresh ทันที + เริ่ม loop ใหม่
    func bindLifecycleRefresh() {
        let ws = NSWorkspace.shared.notificationCenter

        ws.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.logger.log("หน้าจอ sleep — หยุด auto-refresh (ประหยัดโควต้า API)")
                self?.stopAutoRefresh()
            }
        }
        ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.logger.log("หน้าจอตื่น — refresh ทันที + เริ่ม auto-refresh ใหม่")
                await self.refresh()
                self.startAutoRefresh()
            }
        }
        ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.logger.log("Mac ตื่นจาก sleep — refresh ทันที + เริ่ม auto-refresh ใหม่")
                await self.refresh()
                self.startAutoRefresh()
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }
}
