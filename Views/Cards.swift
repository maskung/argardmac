import SwiftUI
import os

// MARK: - Hero Card — อุณหภูมิใหญ่สุดอลังการ + นาฬิกา

struct HeroCard: View {
    let store: WeatherStore

    private static let heroLog = Logger(subsystem: "th.suphanutthanyaboon.argard", category: "hero")
    private static var tickCount = 0

    var body: some View {
        // Heartbeat: ให้ทั้งการ์ดถูกประเมินใหม่ทุก 1 วิ — ค่าอุณหภูมิ/ความชื้น/Updated
        // อ่านจาก store ตรง ๆ ทุก tick จึงไม่มีทางค้างบนจอแม้ notification ของ
        // ObservableObject จะหลุดไปชั่วคราว (อาการที่เจอกับโปรเซสข้ามคืน)
        TimelineView(.periodic(from: .now, by: 1)) { context in
            heroContent(now: context.date)
        }
    }

    private func heroContent(now: Date) -> some View {
        // เครื่องมือวินิจฉัย: log ค่าที่ view อ่านได้จาก store ทุก 10 tick
        Self.tickCount += 1
        if Self.tickCount % 10 == 0 {
            let updated = store.lastUpdated.map { $0.formatted(.dateTime.hour().minute().second()) } ?? "nil"
            Self.heroLog.log("""
                tick#\(Self.tickCount, privacy: .public) อ่านได้ \
                temp=\(store.obs.metric.temp ?? -999, privacy: .public) \
                rh=\(store.obs.humidity ?? -999, privacy: .public) \
                updated=\(updated, privacy: .public)
                """)
        }

        let m = store.obs.metric
        let feel = WX.feeling(m.heatIndex)
        let emoji = store.forecast.first.map { WX.weatherEmoji($0.weatherIcon) } ?? "🌤️"
        let moon = MoonInfo.calculate()

        return HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(store.obs.neighborhood.isEmpty ? store.config.stationID : store.obs.neighborhood) • STATION \(store.config.stationID)")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(Theme.textGold)

                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(WX.fmtInt(m.temp) + "°")
                        .font(.system(size: 88, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textGold)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                    Text(emoji)
                        .font(.system(size: 42))
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                }

                HStack(spacing: 8) {
                    HeroChip(icon: "sparkles", text: "Feels \(WX.fmtInt(m.heatIndex))°C",
                             color: feel.severity.color)
                    HeroChip(icon: "drop.fill", text: WX.fmtInt(store.obs.humidity, suffix: "%"))
                    HeroChip(icon: "wind",
                             text: "\(WX.degToArrow(store.obs.winddir)) \(WX.fmt(m.windSpeed, 0)) km/h")
                }
                Text(feel.emojiText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(feel.severity.color)
            }

            Spacer(minLength: 16)

            // ดวงจันทร์ครึ่งซีกแบบปฏิทินไทยกลางแบนเนอร์
            // (รายละเอียดเฟส/ค่ำ/Illuminated อยู่ในการ์ด Moon Phase แล้ว)
            MoonDisc(phase: moon.phase, size: 86)

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 5) {
                Text(now.formatted(.dateTime.hour().minute().second()))
                    .font(.system(size: 38, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.92))
                Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                if let updated = store.lastUpdated {
                    HStack(spacing: 4) {
                        // จุดกะพริบทุกวินาที — พิสูจน์ว่า heartbeat ยัง render จริง
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)
                            .opacity(Calendar.current.component(.second, from: now) % 2 == 0 ? 0.9 : 0.15)
                        Text("Updated \(updated.formatted(.dateTime.hour().minute().second()))")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .glassCard(corner: 20)
    }
}

struct HeroChip: View {
    let icon: String
    let text: String
    var color: Color = .white.opacity(0.85)

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(.system(size: 12, weight: .medium)).monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.14)))
    }
}

// MARK: - การ์ดทั้ง 8 ของ Dashboard

struct ThermalCard: View {
    let obs: PWSObservation

    var body: some View {
        let m = obs.metric
        let feel = WX.feeling(m.heatIndex)
        Card(title: "Thermal Comfort", systemIcon: "thermometer.medium",
             accent: Theme.fire, badge: WX.fmt(m.temp, 0, suffix: "°C")) {
            InfoRow("🌡️ Temperature", WX.fmt(m.temp, suffix: " °C"))
            InfoRow("🔥 Feels like", WX.fmt(m.heatIndex, suffix: " °C"))
            InfoRow("🤔 Feeling", feel.emojiText, valueColor: feel.severity.color)
            InfoRow("💧 Dew point", WX.fmt(m.dewpt, suffix: " °C"))
            InfoRow("❄️ Wind chill", WX.fmt(m.windChill, suffix: " °C"))
        }
    }
}

struct WindCard: View {
    let obs: PWSObservation

    var body: some View {
        let m = obs.metric
        // API (units=m) ส่งมาเป็น km/h แล้ว — ใช้ตรง ๆ อย่าแปลงซ้ำ (เคยคูณ 3.6 ทำให้ค่าเยิน 3.6 เท่า)
        let speed = m.windSpeed
        let gust = m.windGust
        let desc = WX.wind(speed)
        Card(title: "Wind • Gust", systemIcon: "wind",
             accent: Theme.breeze, badge: WX.fmt(speed, 0, suffix: " km/h")) {
            HStack(spacing: 16) {
                WindCompass(degrees: obs.winddir)
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow("🧭 Direction",
                            "\(WX.degToArrow(obs.winddir)) \(WX.fmtInt(obs.winddir))° \(WX.degToCompass(obs.winddir))")
                    InfoRow("💨 Speed", WX.fmt(speed, suffix: " km/h"))
                    InfoRow("🌪️ Gust", WX.fmt(gust, suffix: " km/h"))
                    InfoRow("📝 Desc", desc.emojiText, valueColor: desc.severity.color)
                }
            }
        }
    }
}

struct RainCard: View {
    let obs: PWSObservation

    var body: some View {
        let m = obs.metric
        let desc = WX.rain(m.precipRate)
        Card(title: "Rainfall", systemIcon: "cloud.rain",
             accent: Theme.rain, badge: WX.fmt(m.precipTotal, 0, suffix: " mm")) {
            InfoRow("📈 Rate", WX.fmt(m.precipRate, 2, suffix: " mm/h"))
            InfoRow("💧 Intensity", desc.emojiText, valueColor: desc.severity.color)
            InfoRow("📅 Today", WX.fmt(m.precipTotal, 1, suffix: " mm"))
        }
    }
}

struct SolarUVCard: View {
    let obs: PWSObservation

    var body: some View {
        let uvDesc = WX.uv(obs.uv)
        let solarDesc = WX.solar(obs.solarRadiation)
        Card(title: "Solar • UV", systemIcon: "sun.max",
             accent: Theme.solar, badge: "UV \(WX.fmtInt(obs.uv))") {
            HStack(spacing: 16) {
                UVGauge(uv: obs.uv)
                    .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow("😎 UV Level", uvDesc.emojiText, valueColor: uvDesc.severity.color)
                    InfoRow("⚡ Solar Rad.", WX.fmt(obs.solarRadiation, 0, suffix: " W/m²"))
                    VStack(alignment: .leading, spacing: 4) {
                        InfoRow("🔆 Intensity", solarDesc.emojiText, valueColor: solarDesc.severity.color)
                        GaugeBar(value: obs.solarRadiation ?? 0, maxValue: 1200, tint: solarDesc.severity.color)
                    }
                }
            }
        }
    }
}

struct HumidityCard: View {
    let obs: PWSObservation

    var body: some View {
        let h = obs.humidity ?? 0
        Card(title: "Humidity", systemIcon: "humidity",
             accent: Theme.water, badge: Self.zoneName(h)) {
            HStack(spacing: 16) {
                HumidityDial(humidity: obs.humidity)
                VStack(alignment: .leading, spacing: 8) {
                    Text("RELATIVE HUMIDITY")
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(1.2)
                        .foregroundStyle(.white.opacity(0.45))
                    // โซนตามหน้าปัด: 0–30 / 30–50 / 50–70 / 70–100 (สีตรงกับแถบบนหน้าปัด)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            levelTag("🏜️ Very Dry", tint: Color(red: 0.96, green: 0.51, blue: 0.13), isActive: h < 30)
                            levelTag("🌵 Dry", tint: Color(red: 0.99, green: 0.72, blue: 0.07), isActive: h >= 30 && h < 50)
                        }
                        HStack(spacing: 5) {
                            levelTag("🌤️ Normal", tint: Color(red: 0.23, green: 0.67, blue: 0.21), isActive: h >= 50 && h < 70)
                            levelTag("💦 Humid", tint: Color(red: 0.11, green: 0.46, blue: 0.74), isActive: h >= 70)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// ชื่อโซนสำหรับ badge ตรงกับโซนบนหน้าปัด
    private static func zoneName(_ h: Double) -> String {
        if h < 30 { return "🏜️ VERY DRY" }
        if h < 50 { return "🌵 DRY" }
        if h < 70 { return "🌤️ NORMAL" }
        return "💦 HUMID"
    }

    private func levelTag(_ text: String, tint: Color, isActive: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(isActive ? AnyShapeStyle(.white)
                                      : AnyShapeStyle(Color.white.opacity(0.45)))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(isActive ? AnyShapeStyle(tint)
                                 : AnyShapeStyle(Color.white.opacity(0.07)),
                        in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(isActive ? 0.25 : 0.08)))
            .shadow(color: isActive ? tint.opacity(0.6) : .clear, radius: 5)
    }
}

struct PressureAQICard: View {
    let obs: PWSObservation
    let air: AQCurrent

    var body: some View {
        let aqDesc = WX.aqi(air.usAqi)
        Card(title: "Barometer • Air Quality", systemIcon: "barometer",
             accent: Theme.mintG, badge: "AQI \(WX.fmtInt(air.usAqi))") {
            HStack(spacing: 16) {
                BarometerGauge(pressure: obs.metric.pressure)
                VStack(alignment: .leading, spacing: 6) {
                    InfoRow("🇺🇸 US AQI",
                            "\(WX.fmtInt(air.usAqi))  \(aqDesc.emojiText)",
                            valueColor: aqDesc.severity.color)
                    AQIBar(aqi: air.usAqi)
                    InfoRow("💨 PM2.5", WX.fmt(air.pm25, 1, suffix: " µg/m³"))
                    InfoRow("🌫️ PM10", WX.fmt(air.pm10, 1, suffix: " µg/m³"))
                }
            }
        }
    }
}

struct MoonCard: View {
    let moon = MoonInfo.calculate()

    var body: some View {
        Card(title: "Moon Phase", systemIcon: "moonphase.full.moon",
              accent: Theme.moonGrad,
              badge: moon.isWanPhra ? "☸️ วันพระ" : nil) {
            VStack(spacing: 10) {
                // จานจันทร์ครึ่งซีกแบบปฏิทินไทย วาดตาม phase จริง (ละเอียดกว่า emoji 8 แบบ)
                HStack(spacing: 14) {
                    MoonDisc(phase: moon.phase, size: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(moon.phaseName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(moon.thaiLunarText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(moon.isWanPhra ? .yellow : .white.opacity(0.85))
                        if moon.isNewMoon {
                            Text("🌑 NEW MOON!").font(.system(size: 11, weight: .bold)).foregroundStyle(.yellow)
                        } else if moon.isFullMoon {
                            Text("🌕 FULL MOON!").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        }
                    }
                    Spacer(minLength: 0)
                }
                Divider().overlay(.white.opacity(0.12))
                InfoRow("📊 Phase", WX.fmt(moon.phase * 100, 1, suffix: "%"))
                InfoRow("💡 Illuminated", WX.fmt(moon.illuminationPct, 1, suffix: "%"))
                if moon.daysSinceNew < 3 {
                    InfoRow("🌑 Since new", WX.fmt(moon.daysSinceNew, 0, suffix: " days"))
                } else {
                    InfoRow("🌑 Until next", WX.fmt(moon.daysUntilNew, 0, suffix: " days"))
                }
                InfoRow("📆 Next new", MoonInfo.thaiBuddhistDate(moon.nextNewMoon))
            }
        }
    }
}

struct SunSeasonCard: View {
    let obs: PWSObservation
    let season = SunAndSeason.season()

    var body: some View {
        let sun = SunAndSeason.sunTimes(lat: obs.lat ?? 0, lon: obs.lon ?? 0)
        Card(title: "Sun Rise/Set • Seasons", systemIcon: "sunrise",
             accent: Theme.gold, badge: "\(season.emoji) \(season.name)") {
            if let sun {
                InfoRow("🌅 Sunrise", sun.sunrise.formatted(.dateTime.hour().minute()))
                InfoRow("🌇 Sunset", sun.sunset.formatted(.dateTime.hour().minute()))
                InfoRow("☀️ Daylight",
                        String(format: "%dh %dm", Int(sun.daylightHours),
                               Int((sun.daylightHours.truncatingRemainder(dividingBy: 1)) * 60)))
                Divider().overlay(.white.opacity(0.12))
                InfoRow("\(season.emoji) Season", season.name)
                InfoRow("📅 Days in", "\(season.daysIn) days")
                InfoRow("⏭️ Next", "\(season.nextSeason) (\(season.daysUntilNext)d)")
            } else {
                Text("No location data")
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
    }
}
