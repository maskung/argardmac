import Foundation

/// ปรับพยากรณ์ด้วยค่าจริงจากเซนเซอร์ในสวน (MOS แบบง่าย)
/// เทียบค่าที่โมเดลคำนวณไว้ย้อนหลัง กับค่าเฉลี่ยรายชั่วโมงของสถานี แล้ว
/// - อุณหภูมิ: บวกส่วนต่างแยกตามชั่วโมงของวัน จาก 7 วันล่าสุด (โมเดลคลาดกลางวัน/กลางคืนไม่เท่ากัน)
/// - ความชื้น: บวกส่วนต่างเฉลี่ย 72 ชม.ล่าสุด (โมเดลมักต่ำกว่าความชื้นจริงใต้ทรงพุ่ม)
/// - ลม: คูณสัดส่วน 72 ชม.ล่าสุด (สถานีอยู่ในสวน ต้นไม้บังลมเป็นสัดส่วน)
/// ทดสอบย้อนหลัง 15 ก.ค.–13 ต.ค. 2026 กับ ICON (พยากรณ์ล่วงหน้า 1 วัน):
/// อุณหภูมิคลาด 1.61 → 1.39 °C, ความชื้น 6.1 → 4.8%, ลม 4.2 → 0.7 km/h
struct SensorCorrection: Equatable {
    var tempOffsetByHour: [Int: Double]   // ชั่วโมงของวัน (0–23, เวลาท้องถิ่น) → °C ที่บวกเพิ่ม
    var humidityOffset: Double            // จุด % ที่บวกเพิ่ม
    var windFactor: Double                // ตัวคูณลม
    var pairedHours: Int                  // จำนวนชั่วโมงที่ใช้คำนวณความชื้น/ลม

    static let shortWindowHours = 72.0
    static let tempWindowDays = 7.0
    static let minPairs = 36
    static let minPerHour = 4

    /// past: ค่าโมเดลย้อนหลัง (ทุกชั่วโมง hh:00) / history: ค่าเฉลี่ยรายชั่วโมงของสถานี
    static func compute(past: [OWForecastItem], history: [PWSHourlyObs], now: Date = Date()) -> SensorCorrection? {
        let model = Dictionary(past.map { ($0.dt, $0) }, uniquingKeysWith: { a, _ in a })
        let shortFrom = now.addingTimeInterval(-shortWindowHours * 3600)
        let tempFrom = now.addingTimeInterval(-tempWindowDays * 86400)
        let cal = Calendar.current
        var tempDiffs: [Int: [Double]] = [:]
        var rhDiffs: [Double] = []
        var windObs = 0.0, windModel = 0.0
        for row in history {
            guard let start = row.hourStart, start >= tempFrom, start < now else { continue }
            // ค่าเฉลี่ยของสถานีช่วง hh:00–hh:59 เทียบกับค่าโมเดลเฉลี่ยของ hh:00 และ hh+1:00
            let t = start.timeIntervalSince1970
            guard let a = model[t], let b = model[t + 3600] else { continue }
            if let o = row.tempAvg, let ma = a.temp, let mb = b.temp {
                tempDiffs[cal.component(.hour, from: start), default: []].append(o - (ma + mb) / 2)
            }
            guard start >= shortFrom else { continue }
            if let o = row.humidityAvg, let ma = a.humidity, let mb = b.humidity {
                rhDiffs.append(o - (ma + mb) / 2)
            }
            if let o = row.windspeedAvg, let ma = a.windSpeed, let mb = b.windSpeed {
                windObs += o / 3.6                    // km/h → m/s (หน่วยเดียวกับพยากรณ์)
                windModel += (ma + mb) / 2
            }
        }
        let tempOffsets = tempDiffs.compactMapValues { d -> Double? in
            d.count >= minPerHour ? min(6, max(-6, d.reduce(0, +) / Double(d.count))) : nil
        }
        let shortOK = rhDiffs.count >= minPairs
        guard shortOK || !tempOffsets.isEmpty else { return nil }
        let offset = shortOK ? min(20, max(-20, rhDiffs.reduce(0, +) / Double(rhDiffs.count))) : 0
        let factor = shortOK && windModel > 1 ? min(1.5, max(0.1, windObs / windModel)) : 1
        return SensorCorrection(tempOffsetByHour: tempOffsets, humidityOffset: offset,
                                windFactor: factor, pairedHours: rhDiffs.count)
    }

    /// ค่าปรับอุณหภูมิของเวลา hh:00 — อยู่ที่รอยต่อของช่วงชั่วโมง hh-1 กับ hh จึงเฉลี่ยสองช่วง
    func tempOffset(at date: Date) -> Double {
        let h = Calendar.current.component(.hour, from: date)
        let around = [tempOffsetByHour[(h + 23) % 24], tempOffsetByHour[h]].compactMap { $0 }
        return around.isEmpty ? 0 : around.reduce(0, +) / Double(around.count)
    }

    func apply(_ items: [OWForecastItem]) -> [OWForecastItem] {
        items.map { item in
            var x = item
            let dT = tempOffset(at: Date(timeIntervalSince1970: item.dt))
            x.temp = item.temp.map { $0 + dT }
            x.feelsLike = item.feelsLike.map { $0 + dT }
            x.humidity = item.humidity.map { min(100, max(0, $0 + humidityOffset)) }
            x.windSpeed = item.windSpeed.map { $0 * windFactor }
            return x
        }
    }

    /// สรุปสั้นสำหรับแสดงบนจอ เช่น "อุณหภูมิ -1.2…+0.8° • ความชื้น +6% • ลม ×0.13"
    var summary: String {
        var parts: [String] = []
        if let lo = tempOffsetByHour.values.min(), let hi = tempOffsetByHour.values.max() {
            parts.append(String(format: "อุณหภูมิ %+.1f…%+.1f°", lo, hi))
        }
        if pairedHours >= Self.minPairs {
            parts.append(String(format: "ความชื้น %+.0f%%", humidityOffset))
            parts.append(String(format: "ลม ×%.2f", windFactor))
        }
        return parts.joined(separator: " • ")
    }
}

/// ยึดพยากรณ์ชั่วโมงแรก ๆ เข้าหาค่าเซนเซอร์ตอนนี้ แล้วค่อย ๆ จางกลับไปหาค่าโมเดล
/// (เช่น ฝนเพิ่งตก อากาศเย็นกว่าที่โมเดลคิด 2° — ชั่วโมงถัดไปก็น่าจะยังเย็นกว่า)
/// ทดสอบย้อนหลัง 3 เดือน: ชั่วโมงถัดไปอุณหภูมิคลาด 1.43 → 0.92 °C, ความชื้น 6.0 → 2.8%
/// ค่าจางที่ดีที่สุด: อุณหภูมิ 2 ชม., ความชื้น 4 ชม. (ยึดไว้ตลอดโดยไม่จางกลับแย่กว่าไม่ทำ)
enum Nowcast {
    static let tempTau = 2.0               // ชม.
    static let humidityTau = 4.0           // ชม.
    static let maxObsAge: TimeInterval = 30 * 60

    /// ส่วนต่าง ณ ตอนนี้ (ค่าเซนเซอร์ − ค่าพยากรณ์)
    struct Anchor: Equatable {
        var tempError: Double?
        var humidityError: Double?
    }

    static func anchor(_ items: [OWForecastItem], obs: PWSObservation,
                       now: Date = Date()) -> ([OWForecastItem], Anchor?) {
        // ใช้เฉพาะค่าเซนเซอร์ที่สด — ค่าเก่าจะดึงพยากรณ์ผิดทาง
        guard let t = obs.obsTimeUtc, now.timeIntervalSince(t) < maxObsAge else { return (items, nil) }
        let at = t.timeIntervalSince1970
        // ค่าพยากรณ์ ณ เวลาที่เซนเซอร์วัด (เส้นตรงระหว่างสองชั่วโมงที่คร่อมอยู่)
        func modelValue(_ key: KeyPath<OWForecastItem, Double?>) -> Double? {
            guard let i = items.lastIndex(where: { $0.dt <= at }), i + 1 < items.count,
                  let a = items[i][keyPath: key], let b = items[i + 1][keyPath: key] else { return nil }
            let w = (at - items[i].dt) / (items[i + 1].dt - items[i].dt)
            return a + (b - a) * w
        }
        let tempErr = both(obs.metric.temp, modelValue(\.temp)).map { min(8, max(-8, $0.0 - $0.1)) }
        let rhErr = both(obs.humidity, modelValue(\.humidity)).map { min(40, max(-40, $0.0 - $0.1)) }
        guard tempErr != nil || rhErr != nil else { return (items, nil) }

        let anchored = items.map { item -> OWForecastItem in
            var x = item
            let lead = max(0, (item.dt - at) / 3600)
            if let e = tempErr {
                let d = e * exp(-lead / tempTau)
                x.temp = item.temp.map { $0 + d }
                x.feelsLike = item.feelsLike.map { $0 + d }
            }
            if let e = rhErr {
                x.humidity = item.humidity.map { min(100, max(0, $0 + e * exp(-lead / humidityTau))) }
            }
            return x
        }
        return (anchored, Anchor(tempError: tempErr, humidityError: rhErr))
    }

    /// Optional ทั้งสองตัวมีค่า → คู่ค่า
    private static func both(_ a: Double?, _ b: Double?) -> (Double, Double)? {
        guard let a, let b else { return nil }
        return (a, b)
    }
}
