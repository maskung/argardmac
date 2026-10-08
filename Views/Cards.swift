import SwiftUI

// MARK: - Hero Card — อุณหภูมิใหญ่สุดอลังการ + นาฬิกา

struct HeroCard: View {
    let store: WeatherStore

    var body: some View {
        let m = store.obs.metric
        let feel = WX.feeling(m.heatIndex)
        let emoji = store.forecast.first.map { WX.weatherEmoji($0.weatherIcon) } ?? "🌤️"

        HStack(alignment: .center, spacing: 20) {
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
                             text: "\(WX.degToArrow(store.obs.winddir)) \(WX.fmt(WX.msToKmh(m.windSpeed), 0)) km/h")
                }
                Text(feel.emojiText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(feel.severity.color)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 5) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(context.date.formatted(.dateTime.hour().minute().second()))
                        .font(.system(size: 38, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.92))
                }
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                if let updated = store.lastUpdated {
                    Text("Updated \(updated.formatted(.dateTime.hour().minute().second()))")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
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
        let speed = WX.msToKmh(m.windSpeed)
        let gust = WX.msToKmh(m.windGust)
        let desc = WX.wind(speed)
        Card(title: "Wind • Gust", systemIcon: "wind",
             accent: Theme.breeze, badge: WX.fmt(speed, 0, suffix: " km/h")) {
            InfoRow("🧭 Direction",
                    "\(WX.degToArrow(obs.winddir)) \(WX.fmtInt(obs.winddir))° \(WX.degToCompass(obs.winddir))")
            InfoRow("💨 Speed", WX.fmt(speed, suffix: " km/h"))
            InfoRow("🌪️ Gust", WX.fmt(gust, suffix: " km/h"))
            InfoRow("📝 Desc", desc.emojiText, valueColor: desc.severity.color)
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
            InfoRow("☀️ UV Index", WX.fmtInt(obs.uv), valueColor: uvDesc.severity.color)
            InfoRow("😎 UV Level", uvDesc.emojiText, valueColor: uvDesc.severity.color)
            InfoRow("⚡ Solar Rad.", WX.fmt(obs.solarRadiation, 0, suffix: " W/m²"))
            VStack(alignment: .leading, spacing: 4) {
                InfoRow("🔆 Intensity", solarDesc.emojiText, valueColor: solarDesc.severity.color)
                GaugeBar(value: obs.solarRadiation ?? 0, maxValue: 1200, tint: solarDesc.severity.color)
            }
        }
    }
}

struct HumidityCard: View {
    let obs: PWSObservation

    var body: some View {
        let desc = WX.humidity(obs.humidity)
        return Card(title: "Humidity", systemIcon: "humidity",
                    accent: Theme.water, badge: desc.emojiText) {
            VStack(spacing: 6) {
                Text(WX.fmtInt(obs.humidity, suffix: "%"))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Theme.water)
                Text("Relative Humidity")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.vertical, 4)
        }
    }
}

struct PressureAQICard: View {
    let obs: PWSObservation
    let air: AQCurrent

    var body: some View {
        let aqDesc = WX.aqi(air.usAqi)
        Card(title: "Barometer • Air Quality", systemIcon: "barometer",
             accent: Theme.mintG, badge: "AQI \(WX.fmtInt(air.usAqi))") {
            InfoRow("🌡️ Pressure", WX.fmt(obs.metric.pressure, 0, suffix: " hPa"))
            Divider().overlay(.white.opacity(0.12))
            InfoRow("🇺🇸 US AQI",
                    "\(WX.fmtInt(air.usAqi))  \(aqDesc.emojiText)",
                    valueColor: aqDesc.severity.color)
            InfoRow("💨 PM2.5", WX.fmt(air.pm25, 1, suffix: " µg/m³"))
            InfoRow("🌫️ PM10", WX.fmt(air.pm10, 1, suffix: " µg/m³"))
        }
    }
}

struct MoonCard: View {
    let moon = MoonInfo.calculate()

    var body: some View {
        Card(title: "Moon Phase", systemIcon: "moonphase.full.moon",
              accent: Theme.moonGrad,
              badge: moon.isWanPhra ? "☸️ วันพระ" : nil) {
            VStack(spacing: 6) {
                Text(moon.emoji)
                    .font(.system(size: 44))
                    .shadow(color: Color(red: 0.55, green: 0.45, blue: 1.0).opacity(0.8), radius: 18)
                    .shadow(color: Color(red: 0.55, green: 0.45, blue: 1.0).opacity(0.5), radius: 6)
                Text(moon.phaseName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(moon.thaiLunarText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(moon.isWanPhra ? .yellow : .white.opacity(0.85))
                if moon.isNewMoon {
                    Text("🌑 NEW MOON!").font(.system(size: 12, weight: .bold)).foregroundStyle(.yellow)
                } else if moon.isFullMoon {
                    Text("🌕 FULL MOON!").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                }
                Divider().overlay(.white.opacity(0.12))
                InfoRow("📊 Phase", WX.fmt(moon.phase * 100, 1, suffix: "%"))
                if moon.daysSinceNew < 3 {
                    InfoRow("🌑 Since new", WX.fmt(moon.daysSinceNew, 0, suffix: " days"))
                } else {
                    InfoRow("🌑 Until next", WX.fmt(moon.daysUntilNew, 0, suffix: " days"))
                }
                InfoRow("📆 Next new", moon.nextNewMoon.formatted(.dateTime.month().day()))
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
