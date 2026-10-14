import Foundation
import SwiftUI
import AppKit
import os

/// State กลางของแอพ — เก็บข้อมูลที่ดึงมา + error + เวลาอัปเดตล่าสุด
/// และคุม auto-refresh ตาม REFRESH_SECONDS
@MainActor
final class WeatherStore: ObservableObject {
    enum Tab: Hashable { case dashboard, forecast, agriculture }

    @Published var obs = PWSObservation()
    @Published var forecast: [OWForecastItem] = []
    @Published var air = AQCurrent()
    @Published var errorMessage = ""
    /// สถานีไม่ส่งข้อมูลขึ้น cloud เกิน ~30 นาที — obs ยังเป็นค่าล่าสุดที่เคยได้ (ถ้ามี)
    @Published var stationOffline = false
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var tab: Tab = .dashboard
    /// ค่าปรับแก้พยากรณ์จากเซนเซอร์ (nil = ปิดอยู่ หรือข้อมูลย้อนหลังยังไม่พอ)
    @Published var correction: SensorCorrection?
    /// ส่วนต่างเซนเซอร์ − พยากรณ์ ณ ตอนนี้ ที่ใช้ยึดชั่วโมงแรก ๆ (nil = ไม่ได้ใช้)
    @Published var nowcast: Nowcast.Anchor?

    let config: AppConfig
    private let service: WeatherService
    private var refreshTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "th.suphanutthanyaboon.argard", category: "store")
    private var refreshCount = 0
    private var history: [PWSHourlyObs] = []
    /// พยากรณ์ดิบชุดล่าสุดที่ดึงสำเร็จ — ใช้ต่อเมื่อ Open-Meteo ล่มชั่วคราว (เช่น HTTP 503)
    private var lastForecast: (upcoming: [OWForecastItem], past: [OWForecastItem], at: Date)?
    private var historyFetchedAt: Date?

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
        var obsError = ""
        switch o {
        case .ok(let fresh):
            obs = fresh
            stationOffline = false
        case .offline:
            // ไม่ใช่ error — คงค่าล่าสุดไว้บนจอ แล้วให้ header ขึ้น OFFLINE แทน
            if !stationOffline { logger.log("สถานี offline (weather.com ไม่มีข้อมูลเกิน 30 นาที)") }
            stationOffline = true
        case .failed(let msg):
            obs = PWSObservation()
            stationOffline = false
            obsError = msg
        }
        // ดึงพยากรณ์ไม่สำเร็จ → ใช้ชุดล่าสุดต่อ (ตัดชั่วโมงที่ผ่านไปแล้วออก) แทนการล้างทิ้งทั้งแถว
        var forecastError = f.error
        var upcoming = f.upcoming, past = f.past
        if !upcoming.isEmpty {
            lastForecast = (upcoming, past, Date())
        } else if let last = lastForecast {
            let cutoff = Date().addingTimeInterval(-90 * 60).timeIntervalSince1970
            upcoming = last.upcoming.filter { $0.dt >= cutoff }
            past = last.past
            let at = last.at.formatted(.dateTime.hour().minute())
            forecastError = "พยากรณ์ดึงไม่สำเร็จ (\(f.error)) — แสดงชุดล่าสุดเมื่อ \(at)"
            logger.log("ใช้พยากรณ์ชุดล่าสุด (\(at, privacy: .public)) แทน: \(f.error, privacy: .public)")
        }
        if config.sensorCorrection {
            await refreshHistoryIfNeeded()
            let c = SensorCorrection.compute(past: past, history: history)
            if c != correction {
                logger.log("ค่าปรับแก้พยากรณ์จากเซนเซอร์: \(c?.summary ?? "ข้อมูลไม่พอ", privacy: .public) (\(c?.pairedHours ?? 0, privacy: .public) ชม.)")
            }
            correction = c
        } else {
            correction = nil
        }
        let corrected = correction?.apply(upcoming) ?? upcoming
        if config.sensorCorrection && !stationOffline {
            (forecast, nowcast) = Nowcast.anchor(corrected, obs: obs)
        } else {
            (forecast, nowcast) = (corrected, nil)
        }
        // คุณภาพอากาศก็เช่นกัน — ดึงไม่สำเร็จคงค่าเดิมไว้
        if a.1.isEmpty { air = a.0 }

        // รวม error แบบเดียวกับ Python: obs มาก่อน แล้ว forecast แล้ว aqi
        let errors = [obsError, forecastError, a.1].filter { !$0.isEmpty }
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

    /// ประวัติรายชั่วโมงของสถานีเปลี่ยนชั่วโมงละครั้ง — ดึงใหม่เมื่อเก่ากว่า 1 ชม.
    private func refreshHistoryIfNeeded() async {
        if let t = historyFetchedAt, Date().timeIntervalSince(t) < 3600, !history.isEmpty { return }
        let (rows, err) = await service.fetchHourlyHistory()
        if err.isEmpty, !rows.isEmpty {
            history = rows
            historyFetchedAt = Date()
        } else if !err.isEmpty {
            logger.error("ดึงประวัติรายชั่วโมงไม่ได้: \(err, privacy: .public)")
        }
    }

    /// ที่มาของพยากรณ์ สำหรับแสดงบนจอ/ส่งให้ Gemini เช่น "UKMO • ปรับด้วยเซนเซอร์: ความชื้น +6% • ลม ×0.45"
    var forecastSourceText: String {
        let names = ["ukmo_seamless": "UKMO", "icon_seamless": "ICON", "gfs_seamless": "GFS",
                     "ecmwf_ifs025": "ECMWF", "gem_seamless": "GEM", "jma_seamless": "JMA",
                     "meteofrance_seamless": "Météo-France", "cma_grapes_global": "CMA", "best_match": "Best match", "": "Best match"]
        let model = names[config.forecastModel] ?? config.forecastModel
        var parts = [model]
        if let c = correction { parts.append("ปรับด้วยเซนเซอร์: \(c.summary)") }
        if let e = nowcast?.tempError { parts.append(String(format: "ตอนนี้ต่างจากโมเดล %+.1f°", e)) }
        return parts.joined(separator: " • ")
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
