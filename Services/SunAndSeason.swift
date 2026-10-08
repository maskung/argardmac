import Foundation

/// คำนวณเวลาพระอาทิตย์ขึ้น–ตก (สูตร近似เดียวกับ Python เดิม + แก้ timezone/longitude)
/// และข้อมูลฤดูกาลตามวันที่ดาราศาสตร์
struct SunInfo {
    let sunrise: Date
    let sunset: Date
    var daylightHours: Double { sunset.timeIntervalSince(sunrise) / 3600 }
}

enum SunAndSeason {

    static func sunTimes(lat: Double, lon: Double, date: Date = Date()) -> SunInfo? {
        guard lat != 0 || lon != 0 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        let tz = TimeZone.current
        cal.timeZone = tz
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: date) ?? 1

        // สูตรประมาณจากโปรแกรมเดิม
        let declination = 23.45 * sin((360.0 / 365.0 * Double(dayOfYear - 80)) * .pi / 180)
        let cosH = -tan(lat * .pi / 180) * tan(declination * .pi / 180)
        guard cosH >= -1, cosH <= 1 else { return nil }
        let hourAngle = acos(cosH) * 180 / .pi
        let solarSunrise = 12.0 - hourAngle / 15.0
        let solarSunset = 12.0 + hourAngle / 15.0

        // แปลง solar time → เวลาท้องถิ่น (แก้ตาม longitude + timezone)
        let tzOffsetHours = Double(tz.secondsFromGMT(for: date)) / 3600.0
        let correctionHours = (tzOffsetHours * 15.0 - lon) / 15.0
        let startOfDay = cal.startOfDay(for: date)

        func clockDate(fromSolar solarHour: Double) -> Date {
            let localHour = solarHour + correctionHours
            return startOfDay.addingTimeInterval(localHour * 3600)
        }
        return SunInfo(sunrise: clockDate(fromSolar: solarSunrise),
                       sunset: clockDate(fromSolar: solarSunset))
    }

    struct SeasonInfo {
        let name: String
        let emoji: String
        let daysIn: Int
        let daysUntilNext: Int
        let nextSeason: String
    }

    /// ฤดูตามวันดาราศาสตร์ (เหนือเส้นศูนย์สูตร) — thresholds ตรงกับ Python เดิม
    static func season(for date: Date = Date()) -> SeasonInfo {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let d = cal.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = cal.component(.year, from: date)
        let isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
        let daysInYear = isLeap ? 366 : 365

        if d < 79 {
            let start = isLeap ? 356 : 355
            return SeasonInfo(name: "Winter", emoji: "❄️",
                              daysIn: d + (daysInYear - start),
                              daysUntilNext: 79 - d, nextSeason: "Spring 🌸")
        } else if d < 172 {
            return SeasonInfo(name: "Spring", emoji: "🌸",
                              daysIn: d - 79, daysUntilNext: 172 - d,
                              nextSeason: "Summer ☀️")
        } else if d < 265 {
            return SeasonInfo(name: "Summer", emoji: "☀️",
                              daysIn: d - 172, daysUntilNext: 265 - d,
                              nextSeason: "Autumn 🍂")
        } else if d < 355 {
            return SeasonInfo(name: "Autumn", emoji: "🍂",
                              daysIn: d - 265, daysUntilNext: 355 - d,
                              nextSeason: "Winter ❄️")
        } else {
            return SeasonInfo(name: "Winter", emoji: "❄️",
                              daysIn: d - 355,
                              daysUntilNext: daysInYear - d + 79,
                              nextSeason: "Spring 🌸")
        }
    }
}
