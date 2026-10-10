import SwiftUI

/// หน้าพยากรณ์ 12 ชั่วโมงข้างหน้า (แทนโหมดกด Enter ใน Python เดิม)
struct ForecastView: View {
    // เช่นเดียวกับ DashboardView — กันค่าค้างสองชั้น
    @ObservedObject var store: WeatherStore
    private let columns = [GridItem(.adaptive(minimum: 240), spacing: 14)]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            forecastContent
        }
    }

    private var forecastContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("HOURLY FORECAST • NEXT 12 HOURS")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(Theme.textGold)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(store.forecast.prefix(12).enumerated()), id: \.offset) { _, hour in
                        ForecastHourCard(hour: hour)
                    }
                }
            }
            .padding(16)
        }
    }
}

struct ForecastHourCard: View {
    let hour: OWForecastItem

    var body: some View {
        let time = Date(timeIntervalSince1970: hour.dt)
        Card(title: time.formatted(.dateTime.hour().minute()),
             systemIcon: "clock",
             accent: Theme.violet,
             badge: WX.fmt(hour.temp, 1, suffix: "°C")) {
            HStack(spacing: 8) {
                Text(WX.weatherEmoji(hour.weatherIcon))
                    .font(.system(size: 26))
                Text(hour.weatherDesc.capitalized)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider().overlay(.white.opacity(0.12))
            InfoRow("🌡️ Temp", WX.fmt(hour.temp, 1, suffix: " °C"))
            InfoRow("🤔 Feels", WX.fmt(hour.feelsLike, 1, suffix: " °C"))
            InfoRow("💧 Humid", WX.fmt(hour.humidity, 0, suffix: " %"))
            InfoRow("☁️ Clouds", WX.fmt(hour.clouds, 0, suffix: " %"))
            InfoRow("💨 Wind",
                    "\(WX.degToArrow(hour.windDeg)) \(WX.fmt(WX.msToKmh(hour.windSpeed), 0, suffix: " km/h"))")
            InfoRow("👁️ Vis", WX.fmt((hour.visibility ?? 0) / 1000, 1, suffix: " km"))
            InfoRow("🌡️ Pres", WX.fmt(hour.pressure, 0, suffix: " hPa"))
            InfoRow("🌧️ Precip", WX.fmtInt((hour.pop ?? 0) * 100, suffix: " %"))
            if let rain = hour.rain, rain > 0 {
                InfoRow("☔ Rain", WX.fmt(rain, 2, suffix: " mm"))
            }
        }
    }
}
