import SwiftUI

/// หน้า Dashboard — Hero + การ์ด 8 ใบ + แถบพยากรณ์รายชั่วโมง
struct DashboardView: View {
    // สองชั้นกันค่าค้าง (บทเรียนจากหลายเซสชัน): @ObservedObject ทำให้ได้ค่าใหม่
    // ทันทีที่ store.refresh() สำเร็จ และ TimelineView หัวใจของตัวเอง (แบบ HeroCard)
    // ขับใหม่ทุกวินาที แม้ Live ภายนอกหรือ objectWillChange จะหยุดชะงัก
    @ObservedObject var store: WeatherStore
    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 14)]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            dashboardContent
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                HeroCard(store: store)

                LazyVGrid(columns: columns, spacing: 14) {
                    ThermalCard(obs: store.obs)
                    WindCard(obs: store.obs)
                    RainCard(obs: store.obs)
                    SolarUVCard(obs: store.obs)
                    HumidityCard(obs: store.obs)
                    PressureAQICard(obs: store.obs, air: store.air)
                    MoonCard()
                    SunSeasonCard(obs: store.obs)
                }

                if !store.forecast.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HOURLY FORECAST")
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(1.5)
                            .foregroundStyle(Theme.textGold)
                            .padding(.horizontal, 2)
                        ScrollView(.horizontal, showsIndicators: true) {
                            HStack(spacing: 10) {
                                ForEach(store.forecast.prefix(10), id: \.dt) { hour in
                                    CompactHourCell(hour: hour)
                                }
                            }
                            .padding(2)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
            }
            .padding(16)
        }
    }
}

/// เซลล์ย่อยของพยากรณ์รายชั่วโมง (แถบล่างของ Dashboard)
struct CompactHourCell: View {
    let hour: OWForecastItem

    var body: some View {
        VStack(spacing: 5) {
            Text(Date(timeIntervalSince1970: hour.dt).formatted(.dateTime.hour().minute()))
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .kerning(0.5)
                .foregroundStyle(Theme.textGold)
            Text(WX.weatherEmoji(hour.weatherIcon))
                .font(.system(size: 24))
            Text(WX.fmt(hour.temp, 1, suffix: "°"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            HStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 8))
                Text(WX.fmtInt((hour.pop ?? 0) * 100, suffix: "%"))
                    .font(.system(size: 11))
            }
            .monospacedDigit()
            .foregroundStyle(Color(red: 0.42, green: 0.65, blue: 1.0))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(width: 92)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.12))
        )
    }
}
