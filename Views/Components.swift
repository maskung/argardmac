import SwiftUI

// MARK: - Live — บังคับให้ subtree ถูกประเมินใหม่ทุก 1 วินาที
/// ปกติ SwiftUI อัพเดท view ตาม objectWillChange ของ store แต่เครื่องนี้พบว่า
/// กลไกนั้นหยุดทำงานหลังแอพถูก force-quit แล้ว restore (header/การ์ดค้างที่ค่าเก่า
/// ทั้งที่ store มีค่าใหม่ — ดูหลักฐานใน log หมวด hero) — Live ใช้ TimelineView
/// ขับเองทุกวินาที ทำให้ทุก view ที่อ่าน store ภายในได้ค่าสดเสมอ (แบบเดียวกับที่
/// HeroCard ใช้แล้วได้ผลตลอด 4 ชั่วโมง)
struct Live<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            content()
        }
    }
}

// MARK: - การ์ด (แทน Panel ของ rich) — สไตล์กระจกหรูหรา

struct Card<Content: View>: View {
    let title: String
    let systemIcon: String
    var accent: LinearGradient = Theme.gold
    var badge: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 1, y: 0.5)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accent, in: Capsule())
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 245, alignment: .topLeading)
        .glassCard()
    }
}

// MARK: - แถวข้อมูล  label ..... value

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white

    init(_ label: String, _ value: String, valueColor: Color = .white) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 8)
            Text(value)
                .monospacedDigit()
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
        .font(.system(size: 13))
    }
}

// MARK: - มาตรวัดความชื้นแบบหน้าปัดอนาล็อก (โซน VERY DRY → DRY → NORMAL → HUMID)

/// เข็มแบบเรียวแหลม (ปลายแหลม โคนกว้าง)
struct DialNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w / 2, y: 0))          // ปลายแหลม
        p.addLine(to: CGPoint(x: w, y: h * 0.75))    // บ่าขวา
        p.addLine(to: CGPoint(x: w * 0.62, y: h))    // โคนขวา
        p.addLine(to: CGPoint(x: w * 0.38, y: h))    // โคนซ้าย
        p.addLine(to: CGPoint(x: 0, y: h * 0.75))    // บ่าซ้าย
        p.closeSubpath()
        return p
    }
}

struct HumidityDial: View {
    let humidity: Double?
    private var v: Double { min(max(humidity ?? 0, 0), 100) }
    private var needleAngle: Double { -135.0 + 2.7 * v }   // 0% ล่างซ้าย → 100% ล่างขวา (กวาด 270°)
    private static let ink = Color(red: 0.17, green: 0.17, blue: 0.17)

    var body: some View {
        ZStack {
            face
            zones
            ticks
            numerals
            needle
            hub
            readout
        }
        .frame(width: 118, height: 118)
    }

    /// หน้าปัดขาว + ขอบโลหะ
    private var face: some View {
        ZStack {
            Circle().fill(
                LinearGradient(colors: [.white, Color(red: 0.94, green: 0.95, blue: 0.96)],
                               startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(
                LinearGradient(colors: [Color(red: 0.93, green: 0.94, blue: 0.95),
                                        Color(red: 0.55, green: 0.58, blue: 0.60)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 3)
        }
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    /// แถบโซนสี: 0–30 ส้ม / 30–50 เหลือง / 50–70 เขียว / 70–100 น้ำเงิน
    private var zones: some View {
        ZStack {
            zoneArc(from: 0, to: 30, color: Color(red: 0.96, green: 0.51, blue: 0.13))
            zoneArc(from: 30, to: 50, color: Color(red: 0.99, green: 0.72, blue: 0.07))
            zoneArc(from: 50, to: 70, color: Color(red: 0.23, green: 0.67, blue: 0.21))
            zoneArc(from: 70, to: 100, color: Color(red: 0.11, green: 0.46, blue: 0.74))
        }
    }

    private func zoneArc(from: Double, to: Double, color: Color) -> some View {
        Circle()
            .trim(from: from / 100 * 0.75, to: to / 100 * 0.75)
            .stroke(color, style: StrokeStyle(lineWidth: 11, lineCap: .butt))
            .rotationEffect(.degrees(135))
            .padding(11)
    }

    /// ขีดสเกลละเอียดทุก 5% (ทุก 10 เป็นขีดใหญ่)
    private var ticks: some View {
        ForEach(Array(stride(from: 0.0, through: 100.0, by: 5.0)), id: \.self) { val in
            tick(val)
        }
    }

    private func tick(_ val: Double) -> some View {
        let angle = -135.0 + 2.7 * val
        let decade = Int(val) % 10 == 0
        let line = Capsule()
            .fill(decade ? Self.ink.opacity(0.8) : Self.ink.opacity(0.35))
            .frame(width: decade ? 1.5 : 1, height: decade ? 7 : 4)
            .offset(y: -38)
        return line.rotationEffect(.degrees(angle))
    }

    /// ตัวเลข 0–100 รอบหน้าปัด (ตั้งตรงเสมอ อ่านง่าย)
    private var numerals: some View {
        ForEach([0.0, 20.0, 40.0, 60.0, 80.0, 100.0], id: \.self) { val in
            numeral(val)
        }
    }

    private func numeral(_ val: Double) -> some View {
        let radians = (-135.0 + 2.7 * val) * .pi / 180
        return Text("\(Int(val))")
            .font(.system(size: 9, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Self.ink)
            .offset(x: sin(radians) * 27, y: -cos(radians) * 27)
    }

    /// เข็มแดง + หาง
    private var needle: some View {
        let tail = Capsule()
            .fill(Color(red: 0.82, green: 0.17, blue: 0.17))
            .frame(width: 3, height: 9)
            .offset(y: 8)
        let arm = DialNeedle()
            .fill(Color(red: 0.82, green: 0.17, blue: 0.17))
            .frame(width: 8, height: 32)
            .offset(y: -14)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        return ZStack { tail; arm }
            .rotationEffect(.degrees(needleAngle))
            .animation(.spring(response: 1.0, dampingFraction: 0.6), value: needleAngle)
    }

    private var hub: some View {
        ZStack {
            Circle().fill(Color(red: 0.82, green: 0.17, blue: 0.17)).frame(width: 10, height: 10)
            Circle().fill(Color(red: 0.55, green: 0.10, blue: 0.10)).frame(width: 4, height: 4)
        }
        .shadow(color: .black.opacity(0.3), radius: 2)
    }

    /// ตัวเลขอ่านค่ากลางหน้าปัด (วางต่ำซ้อนโค้งล่างของวงกลม)
    private var readout: some View {
        VStack(spacing: 0) {
            Text(WX.fmtInt(humidity, suffix: "%"))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Self.ink)
            Text("HUMIDITY")
                .font(.system(size: 6.5, weight: .bold))
                .kerning(1)
                .foregroundStyle(Self.ink.opacity(0.6))
        }
        .offset(y: 35)
    }
}

// MARK: - วงกลม gauge รอบค่า UV (สเกล 0–12)

struct UVGauge: View {
    let uv: Double?
    private var ratio: CGFloat { CGFloat(min(max((uv ?? 0) / 12.0, 0), 1)) }

    var body: some View {
        let color = WX.uv(uv).severity.color
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: 7)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(
                    LinearGradient(colors: [color.opacity(0.6), color],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.6), radius: 6)
            VStack(spacing: 0) {
                Text(WX.fmtInt(uv))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Text("UV")
                    .font(.system(size: 9, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .animation(.easeInOut(duration: 0.7), value: ratio)
    }
}

// MARK: - เข็มทิศลม — เข็มหมุนตามทิศทางลมจริง

struct CompassNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

struct WindCompass: View {
    let degrees: Double?
    private var deg: Double { degrees ?? 0 }

    var body: some View {
        ZStack {
            // หน้าปัด
            Circle().stroke(.white.opacity(0.14), lineWidth: 1.5)
            // ขีดสเกลทุก 45° (หลักใหญ่ = ทิศหลัก)
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(i % 2 == 0 ? Color.white.opacity(0.45) : Color.white.opacity(0.2))
                    .frame(width: i % 2 == 0 ? 2 : 1.5,
                           height: i % 2 == 0 ? 8 : 5)
                    .offset(y: -43)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            // ทิศหลัก N E S W
            Text("N").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textGold)
                .offset(y: -32)
            Group {
                Text("E").offset(x: 32)
                Text("S").offset(y: 32)
                Text("W").offset(x: -32)
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.5))

            // เข็ม + ทิศย่อ
            VStack(spacing: 3) {
                ZStack {
                    // หางเข็ม
                    Capsule()
                        .fill(.white.opacity(0.45))
                        .frame(width: 2.5, height: 14)
                        .offset(y: 15)
                    // หัวเข็ม
                    CompassNeedle()
                        .fill(Theme.breeze)
                        .frame(width: 20, height: 24)
                        .shadow(color: .teal.opacity(0.6), radius: 4)
                }
                .rotationEffect(.degrees(deg))
                .animation(.spring(response: 0.9, dampingFraction: 0.65), value: deg)

                Text(WX.degToCompass(deg))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textGold)
            }
        }
        .frame(width: 100, height: 100)
    }
}

// MARK: - หน้าปัดบารอมิเตอร์แบบเข็ม (สเกล 960–1060 hPa)

struct BarometerGauge: View {
    let pressure: Double?
    private let minP = 960.0, maxP = 1060.0
    private var t: Double { min(max(((pressure ?? minP) - minP) / (maxP - minP), 0), 1) }
    private var needleAngle: Double { -135.0 + 270.0 * t }

    var body: some View {
        ZStack {
            zones
            ticks
            numbers
            needle
            Circle().fill(Theme.gold).frame(width: 6, height: 6)
            value
        }
        .frame(width: 100, height: 100)
    }

    /// โซนสี: ต่ำ <1000 ฟ้า • ปกติ 1000–1025 เขียว • สูง >1025 ส้ม
    private var zones: some View {
        ZStack {
            zoneArc(from: 0.0, to: 0.4, color: .cyan)
            zoneArc(from: 0.4, to: 0.65, color: .green)
            zoneArc(from: 0.65, to: 1.0, color: .orange)
        }
    }

    /// ขีดสเกลทุก 20 hPa (ทุก 40 เป็นขีดใหญ่)
    private var ticks: some View {
        ForEach(Array(stride(from: minP, through: maxP, by: 20.0)), id: \.self) { v in
            tickMark(value: v)
        }
    }

    private func tickMark(value v: Double) -> some View {
        let angle = -135.0 + 270.0 * ((v - minP) / 100.0)
        let major = Int(v) % 40 == 0
        let line = Capsule()
            .fill(major ? Color.white.opacity(0.55) : Color.white.opacity(0.25))
            .frame(width: major ? 2 : 1.5, height: major ? 7 : 4)
            .offset(y: -35)
        return line.rotationEffect(.degrees(angle))
    }

    /// ตัวเลข 980 / 1000 / 1020 / 1040 รอบหน้าปัด
    private var numbers: some View {
        ForEach([980.0, 1000.0, 1020.0, 1040.0], id: \.self) { v in
            dialNumber(value: v)
        }
    }

    private func dialNumber(value v: Double) -> some View {
        let radians = (-135.0 + 270.0 * ((v - minP) / 100.0)) * Double.pi / 180
        let text = Text("\(Int(v))")
            .font(.system(size: 7, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.45))
        return text.offset(x: sin(radians) * 24, y: -cos(radians) * 24)
    }

    /// เข็ม + หางเข็ม
    private var needle: some View {
        let tail = Capsule()
            .fill(Color.white.opacity(0.4))
            .frame(width: 2.5, height: 10)
            .offset(y: 7)
        let arm = Capsule()
            .fill(Theme.gold)
            .frame(width: 3, height: 26)
            .offset(y: -9)
            .shadow(color: .yellow.opacity(0.5), radius: 4)
        return ZStack { tail; arm }
            .rotationEffect(.degrees(needleAngle))
            .animation(.spring(response: 1.1, dampingFraction: 0.65), value: needleAngle)
    }

    /// ค่ากดอากาศกลางหน้าปัด
    private var value: some View {
        VStack(spacing: 0) {
            Text(WX.fmt(pressure, 0))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("hPa")
                .font(.system(size: 7, weight: .semibold))
                .kerning(1)
                .foregroundStyle(.white.opacity(0.5))
        }
        .offset(y: 17)
    }

    /// วงโค้งโซนสี (กวาด 270° เว้นช่องล่าง)
    private func zoneArc(from: Double, to: Double, color: Color) -> some View {
        Circle()
            .trim(from: from * 0.75, to: to * 0.75)
            .stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: 5, lineCap: .butt))
            .rotationEffect(.degrees(135))
            .padding(8)
    }
}

// MARK: - แถบสี AQI มาตรฐาน US EPA พร้อมหมุดชี้ค่า

struct AQIBar: View {
    let aqi: Double?
    // (ค่าสิ้นสุดช่วง, สี) ตามมาตรฐาน US EPA
    private let segs: [(Double, Color)] = [
        (50, .green), (100, .yellow), (150, .orange), (200, .red),
        (300, .purple), (500, Color(red: 0.55, green: 0.12, blue: 0.18)),
    ]
    private var ratio: CGFloat { CGFloat(min(max((aqi ?? 0) / 500.0, 0), 1)) }
    private var activeIndex: Int {
        let v = aqi ?? 0
        for (i, s) in segs.enumerated() where v < s.0 { return i }
        return segs.count - 1
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<segs.count, id: \.self) { i in
                            let start = i == 0 ? 0.0 : segs[i - 1].0
                            Rectangle()
                                .fill(segs[i].1.opacity(i == activeIndex ? 0.95 : 0.28))
                                .frame(width: geo.size.width * (segs[i].0 - start) / 500.0)
                                .shadow(color: i == activeIndex ? segs[i].1.opacity(0.7) : .clear, radius: 4)
                        }
                    }
                    .clipShape(Capsule())
                    // หมุดขาวชี้ค่าปัจจุบัน
                    Capsule()
                        .fill(.white)
                        .frame(width: 2.5, height: 18)
                        .position(x: geo.size.width * ratio, y: geo.size.height / 2)
                        .shadow(color: .white.opacity(0.8), radius: 3)
                }
            }
            .frame(height: 18)
            HStack {
                Text("0").foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("250").foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("500").foregroundStyle(.white.opacity(0.4))
            }
            .font(.system(size: 8))
            .monospacedDigit()
        }
        .animation(.easeInOut(duration: 0.7), value: activeIndex)
    }
}

// MARK: - แถบ gauge เรืองแสง (แทน ███░░░░ ของ Python)

struct GaugeBar: View {
    let value: Double
    let maxValue: Double
    var tint: Color = .orange

    var ratio: Double { min(Swift.max(value / maxValue, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.65), tint],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * ratio)
                    .shadow(color: tint.opacity(0.7), radius: 5)
            }
        }
        .frame(height: 8)
        .animation(.easeInOut(duration: 0.4), value: ratio)
    }
}
