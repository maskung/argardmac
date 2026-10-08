import Foundation
import SwiftUI

/// ระดับความรุนแรง → สี (map จาก style ของ rich ใน Python เดิม)
enum Severity {
    case good      // green
    case fair      // yellow
    case warn      // orange
    case danger    // red
    case extreme   // magenta/bold
    case neutral   // dim

    var color: Color {
        switch self {
        case .good: .green
        case .fair: .yellow
        case .warn: .orange
        case .danger: .red
        case .extreme: .purple
        case .neutral: .secondary
        }
    }
}

/// ตัวช่วยแปลงค่า + คำอธิบายต่างๆ (port จาก argard.py)
enum WX {

    static func msToKmh(_ v: Double?) -> Double? {
        guard let v else { return nil }
        return (v * 3.6 * 10).rounded() / 10
    }

    static let compass = ["N","NNE","NE","ENE","E","ESE","SE","SSE",
                          "S","SSW","SW","WSW","W","WNW","NW","NNW"]

    static func degToCompass(_ deg: Double?) -> String {
        guard let deg else { return "-" }
        let d = deg.truncatingRemainder(dividingBy: 360)
        return compass[Int((d + 11.25) / 22.5) % 16]
    }

    static func degToArrow(_ deg: Double?) -> String {
        guard let deg else { return "?" }
        let d = deg.truncatingRemainder(dividingBy: 360)
        return ["↑","↗","→","↘","↓","↙","←","↖"][Int((d + 22.5) / 45) % 8]
    }

    struct Descriptor {
        let emojiText: String   // "🥵 Dangerously Hot"
        let severity: Severity
    }

    // ความรู้สึกจาก heat index
    static func feeling(_ t: Double?) -> Descriptor {
        guard let t else { return Descriptor(emojiText: "🤷 N/A", severity: .neutral) }
        switch t {
        case 40...:  return Descriptor(emojiText: "🥵 Dangerously Hot", severity: .danger)
        case 35..<40: return Descriptor(emojiText: "🔥 Very Hot", severity: .danger)
        case 28..<35: return Descriptor(emojiText: "😊 Warm", severity: .fair)
        case 20..<28: return Descriptor(emojiText: "😌 Comfortable", severity: .good)
        default:     return Descriptor(emojiText: "🥶 Cool", severity: .neutral)
        }
    }

    // ลม (km/h)
    static func wind(_ s: Double?) -> Descriptor {
        guard let s else { return Descriptor(emojiText: "🤷 N/A", severity: .neutral) }
        switch s {
        case ..<2:   return Descriptor(emojiText: "🧘 Calm", severity: .neutral)
        case ..<12:  return Descriptor(emojiText: "🍃 Light", severity: .good)
        case ..<29:  return Descriptor(emojiText: "💨 Moderate", severity: .fair)
        case ..<50:  return Descriptor(emojiText: "🌬️ Strong", severity: .warn)
        case ..<75:  return Descriptor(emojiText: "🌪️ Gale", severity: .danger)
        case ..<103: return Descriptor(emojiText: "⛈️ Storm", severity: .danger)
        default:     return Descriptor(emojiText: "🌀 Hurricane", severity: .extreme)
        }
    }

    // ฝนตก (mm/h)
    static func rain(_ r: Double?) -> Descriptor {
        guard let r else { return Descriptor(emojiText: "🤷 N/A", severity: .neutral) }
        switch r {
        case 0:      return Descriptor(emojiText: "☀️ No Rain", severity: .neutral)
        case ..<2.5: return Descriptor(emojiText: "💧 Light", severity: .good)
        case ..<10:  return Descriptor(emojiText: "🌧️ Moderate", severity: .fair)
        case ..<50:  return Descriptor(emojiText: "⛈️ Heavy", severity: .danger)
        default:     return Descriptor(emojiText: "🌊 Violent", severity: .extreme)
        }
    }

    // UV
    static func uv(_ u: Double?) -> Descriptor {
        guard let u else { return Descriptor(emojiText: "🤷 N/A", severity: .neutral) }
        switch u {
        case ...2:   return Descriptor(emojiText: "😊 Low", severity: .good)
        case ...5:   return Descriptor(emojiText: "😎 Moderate", severity: .fair)
        case ...7:   return Descriptor(emojiText: "😮 High", severity: .warn)
        case ...10:  return Descriptor(emojiText: "🥵 Very High", severity: .danger)
        default:     return Descriptor(emojiText: "😱 Extreme", severity: .extreme)
        }
    }

    // US AQI
    static func aqi(_ aqi: Double?) -> Descriptor {
        guard let aqi else { return Descriptor(emojiText: "🤷 N/A", severity: .neutral) }
        switch aqi {
        case ...50:  return Descriptor(emojiText: "😊 Good", severity: .good)
        case ...100: return Descriptor(emojiText: "😐 Moderate", severity: .fair)
        case ...150: return Descriptor(emojiText: "😮 Unhealthy (Sensitive)", severity: .warn)
        case ...200: return Descriptor(emojiText: "😷 Unhealthy", severity: .danger)
        case ...300: return Descriptor(emojiText: "🤢 Very Unhealthy", severity: .extreme)
        default:     return Descriptor(emojiText: "☠️ Hazardous", severity: .danger)
        }
    }

    // รังสีดวงอาทิตย์ (W/m²) — คงข้อความไทยเหมือนเดิม
    static func solar(_ s: Double?) -> Descriptor {
        guard let s else { return Descriptor(emojiText: "🤷 N/A", severity: .neutral) }
        switch s {
        case ...50:  return Descriptor(emojiText: "🌑 มืด", severity: .neutral)
        case ...150: return Descriptor(emojiText: "🌤️ แสงอ่อน", severity: .neutral)
        case ...350: return Descriptor(emojiText: "☀️ แสงปานกลาง", severity: .good)
        case ...600: return Descriptor(emojiText: "🔆 แสงจัด", severity: .fair)
        case ...850: return Descriptor(emojiText: "🔥 แสงแรง", severity: .warn)
        default:     return Descriptor(emojiText: "💥 แสงรุนแรง", severity: .danger)
        }
    }

    // ความชื้นสัมพัทธ์
    static func humidity(_ h: Double?) -> Descriptor {
        guard let h else { return Descriptor(emojiText: "🤷 N/A", severity: .neutral) }
        switch h {
        case ..<30:  return Descriptor(emojiText: "🌵 Dry", severity: .fair)
        case ..<60:  return Descriptor(emojiText: "🌤️ Normal", severity: .good)
        default:     return Descriptor(emojiText: "💦 Humid", severity: .neutral)
        }
    }

    // icon ของ OpenWeather → emoji
    static func weatherEmoji(_ icon: String) -> String {
        let hasD = icon.contains("d")
        switch true {
        case icon.contains("01"): return hasD ? "☀️" : "🌙"
        case icon.contains("02"): return hasD ? "🌤️" : "☁️"
        case icon.contains("03"), icon.contains("04"): return "☁️"
        case icon.contains("09"), icon.contains("10"): return "🌧️"
        case icon.contains("11"): return "⛈️"
        case icon.contains("13"): return "❄️"
        case icon.contains("50"): return "🌫️"
        default: return "❓"
        }
    }

    // จัดรูปแบบตัวเลขแบบง่าย
    static func fmt(_ v: Double?, _ digits: Int = 1, suffix: String = "") -> String {
        guard let v else { return "-" + suffix }
        return String(format: "%.\(digits)f", v) + suffix
    }
    static func fmtInt(_ v: Double?, suffix: String = "") -> String {
        guard let v else { return "-" + suffix }
        return String(format: "%.0f", v) + suffix
    }
}
