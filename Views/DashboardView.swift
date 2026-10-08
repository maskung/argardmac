import SwiftUI

/// หน้า Dashboard — การ์ด 8 ใบ + แถบพยากรณ์ชั่วโมงถัดไปแบบ compact
struct DashboardView: View {
    let store: WeatherStore
    private let columns = [GridItem(.adaptive(minimum: 290), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ThermalCard(obs: store.obs)
                WindCard(obs: store.obs)
                RainCard(obs: store.obs)
                SolarUVCard(obs: store.obs)
                HumidityCard(obs: store.obs)
                PressureAQICard(obs: store.obs, air: store.air)
                MoonCard()
                SunSeasonCard(obs: store.obs)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if !store.forecast.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hourly Forecast")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: 10) {
                            ForEach(store.forecast.prefix(8), id: \.dt) { hour in
                                CompactHourCell(hour: hour)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
    }
}

/// เซลล์ย่อยของพยากรณ์รายชั่วโมง (แถบล่างของ Dashboard)
struct CompactHourCell: View {
    let hour: OWForecastItem

    var body: some View {
        VStack(spacing: 5) {
            Text(Date(timeIntervalSince1970: hour.dt).formatted(.dateTime.hour().minute()))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(WX.weatherEmoji(hour.weatherIcon))
                .font(.system(size: 22))
            Text(WX.fmt(hour.temp, 1, suffix: "°"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 2) {
                Image(systemName: "drop")
                    .font(.system(size: 8))
                Text(WX.fmtInt((hour.pop ?? 0) * 100, suffix: "%"))
                    .font(.system(size: 11))
            }
            .monospacedDigit()
            .foregroundStyle(.blue)
            .frame(width: 84, alignment: .center)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.08)))
    }
}
