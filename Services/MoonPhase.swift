import Foundation

/// คำนวณเฟสดวงจันทร์ + ปฏิทินจันทรคติไทย (ขึ้น/แรม  x ค่ำ, วันพระ)
/// ใช้สูตรเดียวกับโปรแกรม Python เดิม — อ้างอิง New Moon 6 ม.ค. 2000 18:14 UTC
struct MoonInfo {
    let emoji: String
    let phaseName: String
    let phase: Double            // 0.0–1.0
    let thaiLunarText: String    // "ขึ้น 12 ค่ำ เดือน 11" / "แรม 8 ค่ำ เดือน 12"
    let isWanPhra: Bool
    let isNewMoon: Bool
    let isFullMoon: Bool
    let daysSinceNew: Double
    let daysUntilNew: Double
    let nextNewMoon: Date

    /// สัดส่วนพื้นที่สว่างจริงบนจาน (0–100%) — ต่างจาก phase ที่เป็นตำแหน่งในรอบเดือน
    /// (เช่น แรม 14 ค่ำ phase ~95% ของรอบ แต่จานสว่างจริงแค่ ~2%)
    var illuminationPct: Double { (1 - cos(2 * .pi * phase)) / 2 * 100 }

    static let synodicMonth = 29.53058867

    static func calculate(for date: Date = Date()) -> MoonInfo {
        // New Moon อ้างอิง: 2000-01-06 18:14 UTC
        var ref = DateComponents()
        ref.year = 2000; ref.month = 1; ref.day = 6; ref.hour = 18; ref.minute = 14
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let refDate = utcCal.date(from: ref) ?? date
        let daysPassed = date.timeIntervalSince(refDate) / 86400
        let phase = (daysPassed / synodicMonth).truncatingRemainder(dividingBy: 1)

        var emoji = "🌚", name = "New Moon", isNew = false, isFull = false
        switch phase {
        case ..<0.0625:  (emoji, name, isNew) = ("🌑", "New Moon", true)
        case ..<0.1875:  (emoji, name) = ("🌒", "Waxing Crescent")
        case ..<0.3125:  (emoji, name) = ("🌓", "First Quarter")
        case ..<0.4375:  (emoji, name) = ("🌔", "Waxing Gibbous")
        case ..<0.5625:  (emoji, name, isFull) = ("🌕", "Full Moon", true)
        case ..<0.6875:  (emoji, name) = ("🌖", "Waning Gibbous")
        case ..<0.8125:  (emoji, name) = ("🌗", "Last Quarter")
        default:         (emoji, name) = ("🌘", "Waning Crescent")
        }

        let (thaiText, isWanPhra) = thaiLunar(phase: phase)
        let thaiTextWithMonth = "\(thaiText) เดือน \(thaiLunarMonth(date: date, refDate: refDate))"
        let sinceNew = phase * synodicMonth
        let untilNew = synodicMonth - sinceNew
        return MoonInfo(
            emoji: emoji, phaseName: name, phase: phase,
            thaiLunarText: thaiTextWithMonth, isWanPhra: isWanPhra,
            isNewMoon: isNew, isFullMoon: isFull,
            daysSinceNew: sinceNew, daysUntilNew: untilNew,
            nextNewMoon: date.addingTimeInterval(untilNew * 86400)
        )
    }

    /// เปลี่ยน phase (0–1) → ขึ้น/แรม กี่ค่ำ + เช็ควันพระ (8 ค่ำ / 15 ค่ำ)
    static func thaiLunar(phase: Double) -> (String, Bool) {
        let daysOld = phase * 29.53059
        if daysOld < 14.7653 {
            let day = Int(daysOld) + 1
            return ("ขึ้น \(day) ค่ำ", day == 8 || day == 15)
        } else {
            let day = Int(daysOld - 14.7653) + 1
            return ("แรม \(day) ค่ำ", day == 8 || day == 15)
        }
    }

    /// เดือนทางจันทรคติไทย (1–12) — อิงกฎสงกรานต์ 13–15 เม.ย. ต้องตกใน "เดือน 5"
    /// นับจำนวน lunation ตั้งแต่ new moon ที่เปิดเดือนจันทร์ซึ่งครอบ 15 เม.ย. ล่าสุด
    /// ถึง lunation ปัจจุบัน แล้ววน mod 12 จากเดือน 5
    /// (ไม่กรองอธิกมาส "เดือน 8 หลัก" — ปีที่มี ค่าจะเพี้ยน 1 เดือนช่วงหลังกรกฎาคม
    ///  ถึงสงกรานต์ถัดไป สำหรับงานแสดงผลพยากรณ์อากาศถือว่าใช้ได้)
    static func thaiLunarMonth(date: Date, refDate: Date) -> Int {
        let daysPassed = date.timeIntervalSince(refDate) / 86400
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let year = m >= 4 ? y : y - 1          // ยังไม่ถึงเม.ย. = อิงสงกรานต์ปีก่อน
        let apr15 = cal.date(from: DateComponents(year: year, month: 4, day: 15)) ?? date
        let aprDays = apr15.timeIntervalSince(refDate) / 86400
        let lunationsBetween = Int((daysPassed / synodicMonth).rounded(.down))
            - Int((aprDays / synodicMonth).rounded(.down))
        return ((5 - 1 + lunationsBetween) % 12 + 12) % 12 + 1
    }

    /// วันที่แบบไทยพร้อมปี พ.ศ. เช่น "21 ต.ค. 2569"
    static func thaiBuddhistDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "th_TH")
        f.calendar = Calendar(identifier: .buddhist)
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }
}
