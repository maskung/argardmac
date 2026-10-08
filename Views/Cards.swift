import SwiftUI

// MARK: - การ์ดทั้ง 8 ของ Dashboard (ทำหน้าที่แทน panel ของ Python)

struct ThermalCard: View {
    let obs: PWSObservation

    var body: some View {
        let m = obs.metric
        let feel = WX.feeling(m.heatIndex)
        Card(title: "Thermal Comfort", systemIcon: "thermometer.medium",
             accent: .red, badge: WX.fmt(m.temp, 0, suffix: "°C")) {
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
             accent: .teal, badge: WX.fmt(speed, 0, suffix: " km/h")) {
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
             accent: .blue, badge: WX.fmt(m.precipTotal, 0, suffix: " mm")) {
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
        let uvLevelColor = uvDesc.severity.color
        Card(title: "Solar • UV", systemIcon: "sun.max",
             accent: .orange, badge: "UV \(WX.fmtInt(obs.uv))") {
            InfoRow("☀️ UV Index", WX.fmtInt(obs.uv), valueColor: uvLevelColor)
            InfoRow("😎 UV Level", uvDesc.emojiText, valueColor: uvLevelColor)
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
                    accent: .cyan, badge: desc.emojiText) {
            VStack(spacing: 6) {
                Text(WX.fmtInt(obs.humidity, suffix: "%"))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(desc.severity.color)
                Text("Relative Humidity")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
             accent: .mint, badge: "AQI \(WX.fmtInt(air.usAqi))") {
            InfoRow("🌡️ Pressure", WX.fmt(obs.metric.pressure, 0, suffix: " hPa"))
            Divider()
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
              accent: .indigo,
              badge: moon.isWanPhra ? "☸️ วันพระ" : nil) {
            VStack(spacing: 6) {
                Text(moon.emoji)
                    .font(.system(size: 40))
                Text(moon.phaseName)
                    .font(.system(size: 14, weight: .semibold))
                Text(moon.thaiLunarText)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(moon.isWanPhra ? .yellow : .primary)
                if moon.isNewMoon {
                    Text("🌑 NEW MOON!").font(.system(size: 12, weight: .bold)).foregroundStyle(.yellow)
                } else if moon.isFullMoon {
                    Text("🌕 FULL MOON!").font(.system(size: 12, weight: .bold))
                }
                Divider()
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
             accent: .yellow, badge: "\(season.emoji) \(season.name)") {
            if let sun {
                InfoRow("🌅 Sunrise", sun.sunrise.formatted(.dateTime.hour().minute()))
                InfoRow("🌇 Sunset", sun.sunset.formatted(.dateTime.hour().minute()))
                InfoRow("☀️ Daylight",
                        String(format: "%dh %dm", Int(sun.daylightHours),
                               Int((sun.daylightHours.truncatingRemainder(dividingBy: 1)) * 60)))
                Divider()
                InfoRow("\(season.emoji) Season", season.name)
                InfoRow("📅 Days in", "\(season.daysIn) days")
                InfoRow("⏭️ Next", "\(season.nextSeason) (\(season.daysUntilNext)d)")
            } else {
                Text("No location data")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
    }
}
