import SwiftUI

// MARK: - ไอคอนสภาพอากาศแบบสมจริง (ไอคอนใหญ่กลาง Hero card)
// วาดเองด้วยโค้ดในสไตล์ไอคอน "realistic weather" ที่ผู้ใช้ชี้ (Pinterest):
// เมฆฟูแบบ 3D ไล่เฉด, ดวงอาทิตย์เรืองแสง, เมฆพายุโทนเข้ม — คมทุกขนาด ไม่ใช้รูปจากภายนอก
// เม็ดฝน/ฟ้าแลบเป็นแอนิเมชัน Core Animation อยู่ใน RainNSView (Components.swift)

/// โทนสีเมฆ
enum CloudTone {
    case white, grey, dark

    /// (สว่างสุดด้านบน-ซ้าย, กลาง, ขอบมืด)
    var colors: [Color] {
        switch self {
        case .white: [Color(red: 1.00, green: 1.00, blue: 1.00),
                      Color(red: 0.92, green: 0.94, blue: 0.97),
                      Color(red: 0.68, green: 0.73, blue: 0.81)]
        case .grey:  [Color(red: 0.90, green: 0.92, blue: 0.95),
                      Color(red: 0.70, green: 0.74, blue: 0.80),
                      Color(red: 0.44, green: 0.49, blue: 0.57)]
        case .dark:  [Color(red: 0.62, green: 0.66, blue: 0.75),
                      Color(red: 0.38, green: 0.42, blue: 0.51),
                      Color(red: 0.17, green: 0.19, blue: 0.25)]
        }
    }
}

/// เมฆฟู 3D: ฐานโค้ง + ก้อนกลม 4 ก้อน วาดจากหลังมาหน้า แต่ละก้อนไล่แสงจากซ้ายบน
/// สูง 0.62 เท่าของความกว้าง
struct RealisticCloud: View {
    let tone: CloudTone
    let width: CGFloat

    var body: some View {
        let w = width
        let c = tone.colors
        func lit(_ r: CGFloat) -> RadialGradient {
            RadialGradient(colors: c, center: UnitPoint(x: 0.36, y: 0.28), startRadius: 0, endRadius: r * 1.25)
        }
        func puff(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> some View {
            Circle()
                .fill(lit(w * r))
                .frame(width: w * r * 2, height: w * r * 2)
                .shadow(color: .black.opacity(tone == .dark ? 0.35 : 0.14), radius: w * 0.015, y: w * 0.008)
                .position(x: w * x, y: w * y)
        }
        return ZStack {
            // ฐานเมฆ — เรียบ แบนด้านล่าง
            RoundedRectangle(cornerRadius: w * 0.12, style: .continuous)
                .fill(LinearGradient(colors: [c[1], c[2]], startPoint: .top, endPoint: .bottom))
                .frame(width: w * 0.84, height: w * 0.24)
                .position(x: w * 0.50, y: w * 0.48)
            puff(0.72, 0.39, 0.18)      // ขวาหลัง
            puff(0.27, 0.42, 0.16)      // ซ้าย
            puff(0.50, 0.30, 0.25)      // ก้อนใหญ่กลาง
            puff(0.36, 0.40, 0.15)      // ก้อนหน้า-ซ้ายล่าง
            // เงาด้านล่างของทั้งก้อน ให้ดูมีน้ำหนัก
            RoundedRectangle(cornerRadius: w * 0.12, style: .continuous)
                .fill(LinearGradient(colors: [.clear, c[2].opacity(0.55)], startPoint: .top, endPoint: .bottom))
                .frame(width: w * 0.84, height: w * 0.16)
                .position(x: w * 0.50, y: w * 0.52)
                .blendMode(.multiply)
        }
        .frame(width: w, height: w * 0.62)
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: w * 0.07, y: w * 0.04)
    }
}

/// ดวงอาทิตย์เรืองแสง: แกนเหลืองขาว → ส้ม + แสงเรืองรอบดวง
struct RealisticSun: View {
    let diameter: CGFloat

    var body: some View {
        let d = diameter
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1.0, green: 0.62, blue: 0.10).opacity(0.55), .clear],
                                     center: .center, startRadius: d * 0.35, endRadius: d * 0.95))
                .frame(width: d * 1.9, height: d * 1.9)
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1.00, green: 0.98, blue: 0.78),
                                              Color(red: 1.00, green: 0.84, blue: 0.24),
                                              Color(red: 0.98, green: 0.56, blue: 0.06)],
                                     center: UnitPoint(x: 0.40, y: 0.36), startRadius: 0, endRadius: d * 0.62))
                .frame(width: d, height: d)
                .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.6), radius: d * 0.08)
        }
    }
}

/// ประกอบเป็นไอคอนตาม icon code แบบ OpenWeather — คืน nil ถ้ายังไม่มีแบบสมจริง (ใช้ emoji เดิม)
/// กรอบ size×1.25 กว้าง, size×1.2 สูง เท่า emoji เดิม (ไม่ดัน layout ของ Hero card)
struct RealisticWeatherIcon: View {
    let icon: String
    let size: CGFloat

    enum Kind { case sun, partly, cloudy, rain, storm }

    static func kind(for icon: String) -> Kind? {
        switch true {
        case icon.contains("11"): .storm
        case icon.contains("09"), icon.contains("10"): .rain
        case icon.contains("03"), icon.contains("04"): .cloudy
        case icon.contains("02"): icon.contains("d") ? .partly : .cloudy
        case icon == "01d": .sun
        default: nil                    // กลางคืนฟ้าโปร่ง / หิมะ / หมอก — ยังใช้แบบเดิม
        }
    }

    var body: some View {
        let w = size * 1.25, h = size * 1.2
        ZStack {
            switch Self.kind(for: icon) {
            case .sun:
                RealisticSun(diameter: size * 0.70)
                    .position(x: w / 2, y: h / 2)
            case .partly:
                RealisticSun(diameter: size * 0.56)
                    .position(x: w * 0.38, y: h * 0.36)
                RealisticCloud(tone: .white, width: size * 0.92)
                    .position(x: w * 0.57, y: h * 0.62)
            case .cloudy:
                RealisticCloud(tone: .grey, width: size * 0.72)
                    .position(x: w * 0.63, y: h * 0.38)
                RealisticCloud(tone: .white, width: size * 0.95)
                    .position(x: w * 0.45, y: h * 0.58)
            case .rain:
                RealisticCloud(tone: .grey, width: size * 1.0)
                    .position(x: w / 2, y: h * 0.36)
            case .storm:
                RealisticCloud(tone: .dark, width: size * 1.0)
                    .position(x: w / 2, y: h * 0.36)
            case nil:
                EmptyView()
            }
        }
        .frame(width: w, height: h)
    }
}
