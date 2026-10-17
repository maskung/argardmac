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

// MARK: - MoonDisc — ดวงจันทร์ครึ่งซีกแบบปฏิทินไทย (ละเอียดต่อเนื่องทุกค่ำ)
// emoji จันทร์ใน Unicode มีแค่ 8 แบบ ไม่พอทำ 30 ระดับ จึงวาดจานจันทร์เอง:
// ด้านสว่าง = ครึ่งวงกลมด้านที่ดวงอาทิตย์ส่อง + เส้นแบ่งมืด-สว่าง (เทอร์มิเนเตอร์)
// เป็นครึ่งวงรีที่กว้างแคบตาม phase จริง — ได้เสี้ยวข้างขึ้น/ข้างแรมตามค่ำ

/// รูปส่วนที่สว่างของดวงจันทร์ (phase 0=New, 0.25=First Quarter, 0.5=Full, 0.75=Last Quarter)
struct MoonLitShape: Shape {
    let phase: Double

    func path(in rect: CGRect) -> Path {
        let κ: CGFloat = 0.5523                    // ค่าคงที่สำหรับประมาณ arc ด้วย cubic Bézier
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let T = CGPoint(x: c.x, y: c.y - r)        // ขั้วบน
        let B = CGPoint(x: c.x, y: c.y + r)        // ขั้วล่าง

        let waxing = phase < 0.5                   // ข้างขึ้น: สว่างด้านขวา / ข้างแรม: ด้านซ้าย
        let dir: CGFloat = waxing ? 1 : -1
        let cosx = cos(2 * .pi * phase)            // + = เสี้ยว (crescent), - = เกือบเต็ม (gibbous)
        let rx = r * CGFloat(abs(cosx))            // ครึ่งความกว้างของเทอร์มิเนเตอร์
        let bulge: CGFloat = cosx >= 0 ? dir : -dir

        var p = Path()
        // ขอบนอกด้านสว่าง: ครึ่งวงกลม บน → จุดขอบ → ล่าง
        let E = CGPoint(x: c.x + dir * r, y: c.y)
        p.move(to: T)
        p.addCurve(to: E, control1: CGPoint(x: c.x + dir * κ * r, y: T.y),
                          control2: CGPoint(x: E.x, y: c.y - κ * r))
        p.addCurve(to: B, control1: CGPoint(x: E.x, y: c.y + κ * r),
                          control2: CGPoint(x: c.x + dir * κ * r, y: B.y))
        // เทอร์มิเนเตอร์: ครึ่งวงรี ล่าง → กลาง → บน
        let M = CGPoint(x: c.x + bulge * rx, y: c.y)
        p.addCurve(to: M, control1: CGPoint(x: c.x + bulge * κ * rx, y: B.y),
                          control2: CGPoint(x: M.x, y: c.y + κ * r))
        p.addCurve(to: T, control1: CGPoint(x: M.x, y: c.y - κ * r),
                          control2: CGPoint(x: c.x + bulge * κ * rx, y: T.y))
        p.closeSubpath()
        return p
    }
}

/// จานจันทร์เต็ม — ด้านมืด + ด้านสว่าง พร้อมเรืองแสงม่วงแบบการ์ดเดิม
struct MoonDisc: View {
    let phase: Double
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.13, green: 0.14, blue: 0.22))
                .overlay(Circle().strokeBorder(.white.opacity(0.10)))
            MoonLitShape(phase: phase)
                .fill(LinearGradient(
                    colors: [.white, Color(red: 0.93, green: 0.92, blue: 0.80)],
                    startPoint: .top, endPoint: .bottom))
        }
        .frame(width: size, height: size)
        .shadow(color: Color(red: 0.55, green: 0.45, blue: 1.0).opacity(0.8), radius: 16)
        .shadow(color: Color(red: 0.55, green: 0.45, blue: 1.0).opacity(0.5), radius: 5)
    }
}

// MARK: - การ์ด (แทน Panel ของ rich) — สไตล์กระจกหรูหรา

struct Card<Content: View>: View {
    let title: String
    let systemIcon: String
    var accent: LinearGradient = Theme.gold
    var badge: String? = nil
    /// ความสูงขั้นต่ำ — การ์ดแถวแรกของ Dashboard ใช้ค่าที่ต่ำกว่าเพื่อให้เห็น
    /// Hourly Forecast ครบโดยไม่ต้อง scroll
    var minHeight: CGFloat = 245
    /// ไอคอนเสริมกลางแถวหัวการ์ด ระหว่างชื่อกับป้ายค่า (เช่น ถุงลมของการ์ดลม)
    var accessory: AnyView? = nil
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
                if let accessory {
                    accessory
                    Spacer()
                }
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
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
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

// MARK: - เกจ UV แบบครึ่งวงโค้ง (ตามแบบที่ผู้ใช้ชี้)
// ครึ่งวง 180° ซ้าย(ต่ำ)→ขวา(สูง) แบ่ง 11 ช่องสี คั่นช่องไฟ:
// เขียว 0–2 / เหลือง 3–5 / ส้ม 6–7 / แดง 8–10 / ม่วง 11 (นับจากซ้าย)
// UV ยิ่งมาก เข็มยิ่งกระดิกไปทางขวา (ทิศมาตรฐานตามภาพอ้างอิง — เคยสลับกลับด้าน
// ช่วงสั้นๆ เพราะห่วงวงกลมปลายเข็มตอนนั้นดูเหมือนจุดหมุนจนสับสน พอเอาห่วงออก
// ผู้ใช้ยืนยันทิศเดิม: มากขึ้น = ขวา)
// เข็มขาวแหลมยาวถึงแถบสี หมุนรอบหมุดกลาง (เคยมีห่วงวงกลมปลายเข็มและป้ายชื่อโซน
// รอบนอก — ผู้ใช้ขอเอาออกทั้งคู่)
// (เฟรมสี่เหลี่ยมจตุรัส หมุด/pivot อยู่กึ่งกลางพอดี — เข็มและห่วงใช้รูปแบบ
//  offset แล้ว rotationEffect เหมือนขีดสเกล เพื่อไม่ให้ pivot เพี้ยน)

struct UVSemiGauge: View {
    let uv: Double?
    private var v: Double { min(max(uv ?? 0, 0), 11) }
    // ค่าจำนวนเต็ม v ต้องตก "กลางช่องสี" ของช่องที่ v (ช่องที่ 1..11 นับจากเขียว)
    // จึงเลื่อนครึ่งช่อง: ใช้ (v-0.5)/11 แทน v/11 — ค่า 0 ชี้ปลายซ้ายสุด, ค่า 9 กลางช่องแดง
    // ช่องสุดท้าย (11) กลางช่องม่วงปลายขวา ค่าทศนิยมไหลต่อเนื่องระหว่างกลางช่อง
    private var needleAngle: Double {
        -90.0 + min(max((v - 0.5) / 11.0, 0), 1) * 180.0
    }

    // สีโซนตามแบบอ้างอิง (#A3C43C / #F6E32D / #F7A31C / #ED3B25 / #A955CE)
    private static let zoneGreen = Color(red: 0.64, green: 0.77, blue: 0.24)
    private static let zoneYellow = Color(red: 0.96, green: 0.89, blue: 0.18)
    private static let zoneOrange = Color(red: 0.97, green: 0.64, blue: 0.11)
    private static let zoneRed = Color(red: 0.93, green: 0.23, blue: 0.15)
    private static let zonePurple = Color(red: 0.66, green: 0.33, blue: 0.81)

    var body: some View {
        ZStack {
            segments
            needle
            hub
            readout
        }
        .frame(width: 128, height: 128)
        // ใต้ตัวเลข UV มีที่ว่าง ~11pt ในกรอบ — ตัดออกจาก layout ให้การ์ดเตี้ยลง
        // (ไม่เปลี่ยนเฟรมภายใน จุดหมุนเข็มจึงยังอยู่ที่เดิม)
        .padding(.bottom, -11)
    }

    /// ครึ่งวงบน 11 ช่อง — trim 0.5=9 นาฬิกา → 1.0=3 นาฬิกา (ค่าเพิ่มตามเข็ม)
    private var segments: some View {
        ForEach(0..<11, id: \.self) { i in
            let gap = 0.006   // ~2° ช่องไฟระหว่างช่อง (แบ่งครึ่งหัว-ท้ายให้สมมาตร)
            Circle()
                .trim(from: 0.5 + Double(i) / 22.0 + gap / 2,
                      to: 0.5 + Double(i + 1) / 22.0 - gap / 2)
                .stroke(segColor(i),
                        style: StrokeStyle(lineWidth: 9, lineCap: .butt))
        }
    }

    /// สีช่องที่ i (i=0 ปลายซ้าย … i=10 ปลายขวา) — เขียวซ้าย → ม่วงขวา
    private func segColor(_ i: Int) -> Color {
        switch i {
        case ...1: Self.zoneGreen
        case ...3: Self.zoneYellow
        case ...5: Self.zoneOrange
        case ...8: Self.zoneRed
        default: Self.zonePurple
        }
    }

    /// เข็มขาวเรียวแหลม ปลายทับแถบสี (70pt — ปลายเรียว 10pt สุดท้ายจางเกินตามเห็น
    // เลยต้องยาวพ้นรัศมีแถบ ส่วนที่มองเห็นจึงจรดแถบสีพอดี)
    // ผู้ใช้ขอเอาห่วงวงกลมปลายเข็มออก: ห่วงดูเหมือน "จุดหมุน" จนเข็มดูสลับด้าน
    // ตอนนี้เหลือแต่เข็มแหลมๆ หมุนรอบหมุดกลางตัวจริง
    private var needle: some View {
        SportBaroNeedle()
            .fill(.white)
            .shadow(color: .white.opacity(0.55), radius: 2)
            .frame(width: 5, height: 140)
            .rotationEffect(.degrees(needleAngle))
            .animation(.spring(response: 1.0, dampingFraction: 0.7), value: needleAngle)
    }

    /// หมุดกลางฐาน
    private var hub: some View {
        ZStack {
            Circle().fill(.white).frame(width: 6, height: 6)
            Circle().fill(Color(red: 0.55, green: 0.57, blue: 0.62)).frame(width: 2.2, height: 2.2)
        }
        .shadow(color: .black.opacity(0.5), radius: 1.5)
    }

    /// ค่า UV ตัวเลขใต้หมุด (ในพื้นที่ใต้ครึ่งวง)
    private var readout: some View {
        VStack(spacing: 1) {
            Text(WX.fmtInt(uv))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text("UV INDEX")
                .font(.system(size: 6, weight: .semibold))
                .kerning(1)
                .foregroundStyle(.white.opacity(0.5))
        }
        .offset(y: 36)
    }
}

// MARK: - เกจลมสไตล์การ์ดพยากรณ์โมเดิร์น (ตามแบบที่ผู้ใช้ชี้)
// วงกลมเต็มวง + วงแหวนทองบาง + ขีดรอบวง 60 เส้นสม่ำเสมอทุก 6°
// ไม่มีเข็ม — ใช้หัวลูกศรดำบนวงแหวนชี้เข้าศูนย์กลาง หมุนตามทิศลม
// กลางวงเป็นตัวเลขความเร็วลมดิจิทัล + ค่า gust สีฟ้า

/// หัวลูกศรบนวงแหวน — ปลายแหลมชี้เข้าหาศูนย์กลาง หลังเว้าเล็กน้อย
/// (วางที่ตำแหน่ง 12 นาฬิกาก่อน แล้วหมุนด้วย rotationEffect ตามทิศลม)
struct WindRimArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = w / 2
        var p = Path()
        p.move(to: CGPoint(x: cx, y: h))              // ปลายแหลมชี้เข้าใน
        p.addLine(to: CGPoint(x: w, y: 0))            // ปีกขวาหลัง
        p.addLine(to: CGPoint(x: cx, y: h * 0.32))    // รอยเว้ากลางหลัง
        p.addLine(to: CGPoint(x: 0, y: 0))            // ปีกซ้ายหลัง
        p.closeSubpath()
        return p
    }
}

struct WindGauge: View {
    let speed: Double?
    let gust: Double?
    let degrees: Double?
    private static let accent = Color(red: 0.16, green: 0.66, blue: 0.88)

    var body: some View {
        ZStack {
            // วงแหวนขาวนีออนเรืองแสงรอบวง (เดิมทอง — ผู้ใช้ขอเปลี่ยน)
            Circle().strokeBorder(.white, lineWidth: 2.5)
                .shadow(color: .white.opacity(0.65), radius: 3)
            // ขีดรอบวง 60 เส้น ทุก 6° — สม่ำเสมอ ไม่มีลำดับหลัก-รองตามแบบ
            ForEach(0..<60, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(0.30))
                    .frame(width: 1.2, height: 5)
                    .offset(y: -45)
                    .rotationEffect(.degrees(Double(i) * 6))
            }
            // หัวลูกศรขาวนีออนบนวงแหวน หมุนตามองศาที่ลมพัดมา (FROM bearing)
            WindRimArrow()
                .fill(.white)
                .shadow(color: .white.opacity(0.9), radius: 3.5)
                .frame(width: 10, height: 13)
                .offset(y: -49)
                .rotationEffect(.degrees(degrees ?? 0))
                .animation(.spring(response: 0.9, dampingFraction: 0.7), value: degrees)
            // ตัวเลขกลางวง — ความเร็วลม + หน่วย + gust
            VStack(spacing: 1) {
                Text(WX.fmt(speed, 0))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("km/h")
                    .font(.system(size: 8, weight: .semibold))
                    .kerning(1)
                    .foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 3) {
                    Text("Gust")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(WX.fmt(gust, 0))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Self.accent)
                }
                .padding(.top, 2)
            }
        }
        .frame(width: 110, height: 110)
    }
}

// MARK: - หน้าปัดบารอมิเตอร์สปอร์ตดาร์ก (ตามแบบที่ผู้ใช้ชี้)
// ขอบฟ้าเงาเงา หน้าดำไล่เฉด ขีดขาวรอบวงแบบหน้าปัดนาฬิกา
// วงโซนสี น้ำเงิน→เขียว→แดง กวาด 270° พร้อมไอคอนสภาพอากาศเรียงตามโซน
// (พายุ→ฝน→เมฆ→แดดเมฆ→แดด) เข็มขาวใบมีด ช่องล่างเป็นหน้าต่างค่าดิจิทัล

/// เข็มใบมีดขาว — กว้างสุดที่หมุด (กึ่งกลาง frame) เรียวแหลมปลาย หางถ่วงสั้น
/// (หมุดต้องอยู่กึ่งกลาง frame พอดี rotationEffect จึงหมุนรอบศูนย์หน้าปัด
/// อย่าขยับด้วย offset ก่อนหมุน ไม่งั้น pivot จะเพี้ยนและมุมเข็มบอกค่าผิด)
struct SportBaroNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = w / 2
        var p = Path()
        p.move(to: CGPoint(x: cx, y: 0))                      // ปลายเข็ม
        p.addLine(to: CGPoint(x: cx + w / 2, y: h * 0.46))     // ขอบขวาเหนือหมุด
        p.addLine(to: CGPoint(x: cx + w * 0.30, y: h * 0.53))  // บ่าขวาใต้หมุด
        p.addLine(to: CGPoint(x: cx, y: h * 0.62))            // ปลายหาง (สั้น)
        p.addLine(to: CGPoint(x: cx - w * 0.30, y: h * 0.53))  // บ่าซ้ายใต้หมุด
        p.addLine(to: CGPoint(x: cx - w / 2, y: h * 0.46))     // ขอบซ้ายเหนือหมุด
        p.closeSubpath()
        return p
    }
}

struct BarometerGauge: View {
    let pressure: Double?
    private let minP = 960.0, maxP = 1060.0
    private var t: Double { min(max(((pressure ?? minP) - minP) / (maxP - minP), 0), 1) }
    private var needleAngle: Double { -135.0 + 270.0 * t }

    // โซน: ต่ำ <1000 น้ำเงิน (พายุ/ฝน) • 1000–1025 เขียว (เปลี่ยนแปลง) • >1025 แดง (แล้ง/ร้อน)
    private static let zoneBlue = Color(red: 0.30, green: 0.62, blue: 1.0)
    private static let zoneGreen = Color(red: 0.20, green: 0.75, blue: 0.35)
    private static let zoneRed = Color(red: 0.92, green: 0.28, blue: 0.25)

    var body: some View {
        ZStack {
            dialFace
            tickRing
            zoneBand
            weatherIcons
            needle
            hub
            readout
        }
        .frame(width: 104, height: 104)
    }

    /// หน้าปัดดำไล่เฉด + ขอบฟ้าเงา
    private var dialFace: some View {
        ZStack {
            Circle().fill(
                RadialGradient(colors: [Color(red: 0.30, green: 0.32, blue: 0.36),
                                        Color(red: 0.07, green: 0.08, blue: 0.10)],
                               center: .center, startRadius: 2, endRadius: 52))
            Circle().strokeBorder(
                LinearGradient(colors: [Color(red: 0.45, green: 0.72, blue: 0.98),
                                        Color(red: 0.10, green: 0.35, blue: 0.75),
                                        Color(red: 0.35, green: 0.65, blue: 0.95)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 5)
        }
        .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
    }

    /// ขีดขาวรอบวงแบบหน้าปัดนาฬิกา — ทุก 6° เป็นขีดเล็ก ทุก 30° เป็นขีดใหญ่
    private var tickRing: some View {
        ForEach(0..<60, id: \.self) { i in
            let major = i % 5 == 0
            Capsule()
                .fill(.white.opacity(major ? 0.85 : 0.35))
                .frame(width: major ? 1.6 : 0.8, height: major ? 5.5 : 3)
                .offset(y: -42)
                .rotationEffect(.degrees(Double(i) * 6))
        }
    }

    /// วงโซนสี 3 ช่วง กวาด 270° (เว้นช่องล่างให้หน้าต่างค่า)
    private var zoneBand: some View {
        ZStack {
            bandSegment(startDeg: -135, spanDeg: 108, color: Self.zoneBlue)
            bandSegment(startDeg: -27, spanDeg: 67.5, color: Self.zoneGreen)
            bandSegment(startDeg: 40.5, spanDeg: 94.5, color: Self.zoneRed)
        }
    }

    private func bandSegment(startDeg: Double, spanDeg: Double, color: Color) -> some View {
        Circle()
            .trim(from: 0, to: spanDeg / 360.0)
            .stroke(color.opacity(0.92),
                    style: StrokeStyle(lineWidth: 7, lineCap: .butt))
            // trim ของ Circle เริ่มที่ 3 นาฬิกา ไม่ใช่ 12 — ต้องลบ 90° ให้ start ตรงมุมจริง
            // (สูตรเดียวกับ zoneArc ของ HumidityDial: หมุน +135 เพื่อเริ่มที่ -135°)
            .rotationEffect(.degrees(startDeg - 90))
            .padding(16.5)
    }

    /// ไอคอนสภาพอากาศเรียงตามแนวโซน แทนตัวเลขสเกล
    private let weatherIconSet: [(symbol: String, angle: Double)] = [
        ("cloud.bolt.fill", -95),      // พายุ — โซนน้ำเงิน
        ("cloud.heavyrain.fill", -58), // ฝนตก — โซนน้ำเงิน/เขียว
        ("cloud.fill", -3),            // เมฆ — โซนเขียว
        ("cloud.sun.fill", 47),        // แดดเมฆ — เขียว/แดง
        ("sun.max.fill", 93),          // แดดจัด — โซนแดง
    ]

    private var weatherIcons: some View {
        ForEach(Array(weatherIconSet.enumerated()), id: \.offset) { _, icon in
            let radians = icon.angle * .pi / 180
            Image(systemName: icon.symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.6), radius: 1.5)
                .offset(x: sin(radians) * 22.5, y: -cos(radians) * 22.5)
        }
    }

    /// เข็มขาวใบมีด หมุนตามค่ากดอากาศ (pivot = หมุดกลางหน้าปัด)
    private var needle: some View {
        SportBaroNeedle()
            .fill(LinearGradient(colors: [.white, Color(red: 0.80, green: 0.82, blue: 0.86)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 6, height: 68)
            .rotationEffect(.degrees(needleAngle))
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1.5)
            .animation(.spring(response: 1.1, dampingFraction: 0.65), value: needleAngle)
    }

    /// หมุดขาวกลางหน้าปัด
    private var hub: some View {
        ZStack {
            Circle().fill(.white).frame(width: 5.5, height: 5.5)
            Circle().fill(Color(red: 0.55, green: 0.57, blue: 0.62)).frame(width: 2, height: 2)
        }
        .shadow(color: .black.opacity(0.5), radius: 1.5)
    }

    /// หน้าต่างค่าดิจิทัลช่องล่าง (ตำแหน่ง sub-dial ของแบบอ้างอิง)
    private var readout: some View {
        VStack(spacing: 0) {
            Text(WX.fmt(pressure, 0))
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text("hPa")
                .font(.system(size: 7, weight: .semibold))
                .kerning(1)
                .foregroundStyle(.white.opacity(0.55))
        }
        .offset(y: 22)
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

// MARK: - ไอคอนสภาพอากาศ (emoji + ไอคอนหมอกวาดเอง)

/// แสดงสภาพอากาศจาก icon code แบบ OpenWeather — ใช้ไอคอนแบบสมจริง (WeatherArt.swift) แบบภาพนิ่ง
/// เหลือ emoji เฉพาะแบบที่ยังไม่ได้วาด (หิมะ) — กรอบเท่า emoji ขนาดเดียวกัน ไม่ดัน layout
struct WeatherIconView: View {
    let icon: String
    let size: CGFloat

    var body: some View {
        if RealisticWeatherIcon.kind(for: icon) != nil {
            // ไอคอนแบบสมจริงชุดเดียวกับ Hero card แต่เป็นภาพนิ่ง (ผู้ใช้ขอให้ทั้งแอปเป็นแบบเดียวกัน)
            RealisticWeatherIcon(icon: icon, size: size, animated: false)
        } else {
            Text(WX.weatherEmoji(icon))
                .font(.system(size: size))
        }
    }
}

// MARK: - ไอคอนสภาพอากาศเคลื่อนไหว (ไอคอนใหญ่กลาง Hero card)

/// ฝน: เมฆ ☁️ + เม็ดฝนตกลงมาเป็นสาย / พายุ: เพิ่มฟ้าแลบ ⚡ วาบเป็นจังหวะพร้อมแสงสว่างรอบเมฆ
/// สภาพอากาศอื่นยังเป็นภาพนิ่ง (WeatherIconView) — กรอบขนาดเท่า emoji เดิม ไม่ดัน layout
/// แอนิเมชันใช้ Core Animation (เลเยอร์ละเม็ด + keyframe) ซึ่ง render server ของ macOS
/// เล่นให้เอง — เดิมวาด SwiftUI Canvas ทีละเฟรม 30 fps แล้ว CPU ของแอปขึ้นจาก 6.6% เป็น 30%
struct AnimatedWeatherIcon: View {
    let icon: String
    let size: CGFloat

    /// จำนวนเม็ดฝน (nil = ไม่ใช่ฝน)
    private var drops: Int? {
        if icon.contains("11") { return 18 }      // พายุฝนฟ้าคะนอง
        if icon.contains("10") { return 14 }      // ฝน
        if icon.contains("09") { return 9 }       // ฝนปรอย/ฝนไล่ช้าง
        return nil
    }

    var body: some View {
        if RealisticWeatherIcon.kind(for: icon) != nil {
            // แบบสมจริงที่วาดเอง (WeatherArt.swift) — ฝน/ฟ้าแลบอยู่ใต้เมฆ
            ZStack {
                if let drops {
                    RainLayerView(size: size, drops: drops, thunder: icon.contains("11"))
                }
                RealisticWeatherIcon(icon: icon, size: size)
            }
            .frame(width: size * 1.25, height: size * 1.2)
        } else {
            WeatherIconView(icon: icon, size: size)
                .shadow(color: .black.opacity(0.35), radius: 13, y: 5)
        }
    }
}

/// เลเยอร์ Core Animation ใต้เมฆ: แสงฟ้าแลบ (หลังสุด) → เม็ดฝน → สายฟ้า
private struct RainLayerView: NSViewRepresentable {
    let size: CGFloat
    let drops: Int
    let thunder: Bool

    func makeNSView(context: Context) -> RainNSView { RainNSView(size: size) }
    func updateNSView(_ view: RainNSView, context: Context) {
        view.update(drops: drops, thunder: thunder)
    }
}

/// เม็ดฝน = เลเยอร์ละเม็ด เคลื่อนจากใต้เมฆลงล่างแบบวนซ้ำ (render server เล่นให้ ไม่กิน CPU แอป)
/// ไม่ใช้ CAEmitterLayer: ลองแล้วทิศพุ่งของอนุภาคกลับด้านกับพิกัดตำแหน่ง ฝนลอยขึ้นแทน
final class RainNSView: NSView {
    private let size: CGFloat
    private let glow = CAGradientLayer()
    private let bolt = CALayer()
    private var dropLayers: [CALayer] = []
    private var drops = 0
    private var thunder = false
    private lazy var dropImage = Self.dropImage(length: size * 0.10, width: size * 0.022)

    init(size: CGFloat) {
        self.size = size
        super.init(frame: .zero)
        wantsLayer = true
        // แสงสว่างวาบรอบเมฆ (radial ขาว → ใส)
        glow.type = .radial
        glow.colors = [NSColor(red: 0.62, green: 0.78, blue: 1.0, alpha: 0.95).cgColor,
                       NSColor(red: 0.40, green: 0.60, blue: 1.0, alpha: 0.35).cgColor, NSColor.clear.cgColor]
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.opacity = 0
        layer?.addSublayer(glow)
        // สายฟ้าใต้เมฆ — โผล่เฉพาะตอนแลบ
        bolt.contents = Self.boltImage(size: size * 0.5)
        bolt.contentsGravity = .resizeAspect
        bolt.opacity = 0
        layer?.addSublayer(bolt)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// SwiftUI เรียกทุกครั้งที่ Hero card render (ทุก 1 วิ) — ทำงานเฉพาะเมื่อค่าเปลี่ยนจริง
    /// ไม่งั้นแอนิเมชันจะถูกตั้งใหม่ ฝนกระตุกทุกวินาที
    func update(drops: Int, thunder: Bool) {
        if drops != self.drops {
            self.drops = drops
            dropLayers.forEach { $0.removeFromSuperlayer() }
            dropLayers = (0..<drops).map { _ in
                let l = CALayer()
                l.contents = dropImage
                l.contentsGravity = .resize
                layer?.insertSublayer(l, below: bolt)
                return l
            }
            needsLayout = true
        }
        if thunder != self.thunder {
            self.thunder = thunder
            for l in [glow, bolt] as [CALayer] {
                l.removeAnimation(forKey: "flash")
                if thunder { l.add(Self.flashAnimation(), forKey: "flash") }
            }
        }
    }

    /// เลขสุ่มคงที่ต่อเม็ด (0..<1)
    private func frac(_ x: Double) -> Double { x - x.rounded(.down) }

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        guard w > 0, h > 0 else { return }
        /// เลเยอร์นับ y จากล่างขึ้นบน (กลับกับ SwiftUI) — แปลงจากตำแหน่งที่วัดจากขอบบน
        func fromTop(_ y: CGFloat, height: CGFloat = 0) -> CGFloat { h - y - height }
        let scale = window?.backingScaleFactor ?? 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let r = w * 0.62
        glow.frame = CGRect(x: w / 2 - r, y: fromTop(h * 0.32 - r * 0.8, height: r * 1.6),
                            width: r * 2, height: r * 1.6)
        let b = size * 0.5
        bolt.frame = CGRect(x: w * 0.5 - b / 2, y: fromTop(h * 0.68 - b / 2, height: b), width: b, height: b)

        // เม็ดฝน: ตกจากใต้ฐานเมฆ ลงไป 38% ของกรอบ เอียงซ้ายเล็กน้อย จางตอนเริ่ม/จบ
        let len = size * 0.10, dropW = len * 0.3 + size * 0.044, dropH = len + size * 0.044
        let top = h * 0.50, fall = h * 0.38
        for (i, l) in dropLayers.enumerated() {
            let d = Double(i)
            let x0 = w * (0.26 + 0.50 * frac(d * 0.618))
            let duration = 1 / (1.1 + 0.6 * frac(d * 0.377))       // วินาทีต่อรอบ
            let start = CGPoint(x: x0, y: fromTop(top))
            let end = CGPoint(x: x0 - len * 0.35, y: fromTop(top + fall))
            l.bounds = CGRect(x: 0, y: 0, width: dropW, height: dropH)
            l.contentsScale = scale
            l.position = start
            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = NSValue(point: start)
            move.toValue = NSValue(point: end)
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 0.9, 0.9, 0]
            fade.keyTimes = [0, 0.2, 0.7, 1]
            let g = CAAnimationGroup()
            g.animations = [move, fade]
            g.duration = duration
            g.repeatCount = .infinity
            g.timeOffset = frac(d * 0.731) * duration           // เริ่มคนละจังหวะ
            l.add(g, forKey: "rain")
        }
        for l in [glow, bolt] as [CALayer] { l.contentsScale = scale }
        CATransaction.commit()
    }

    /// จังหวะฟ้าแลบ: ทุก 4.2 วิ แลบสองครั้งติดกันแล้วจางหาย
    private static func flashAnimation() -> CAKeyframeAnimation {
        let a = CAKeyframeAnimation(keyPath: "opacity")
        let d = 4.2
        a.values = [1, 1, 0.15, 0.15, 0.95, 0.95, 0, 0]
        a.keyTimes = [0, 0.07, 0.071, 0.15, 0.151, 0.22, 0.55, d].map { NSNumber(value: $0 / d) }
        a.duration = d
        a.repeatCount = .infinity
        return a
    }

    /// เส้นเม็ดฝนเอียงจากขวาบนลงซ้ายล่าง (ตามทิศตก) — วาดในแกน y ขึ้นบน แสดงในเลเยอร์ตรงตามนี้
    private static func dropImage(length: CGFloat, width: CGFloat) -> CGImage? {
        let w = length * 0.3 + width * 2, h = length + width * 2
        let img = NSImage(size: NSSize(width: w, height: h), flipped: false) { _ in
            let p = NSBezierPath()
            p.move(to: NSPoint(x: w - width, y: h - width))
            p.line(to: NSPoint(x: width + length * 0.05, y: width))
            p.lineWidth = width
            p.lineCapStyle = .round
            NSColor(red: 0.55, green: 0.78, blue: 1.0, alpha: 1).setStroke()
            p.stroke()
            return true
        }
        var rect = NSRect(x: 0, y: 0, width: w * 2, height: h * 2)
        return img.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    /// สายฟ้าซิกแซกสีขาว เรืองแสงสีฟ้ารอบ ๆ (จุดยอดวัดจากขอบบน 0…1)
    private static func boltImage(size b: CGFloat) -> CGImage? {
        let pts: [(CGFloat, CGFloat)] = [(0.58, 0.00), (0.30, 0.50), (0.47, 0.50), (0.32, 1.00),
                                        (0.72, 0.40), (0.54, 0.40), (0.70, 0.00)]
        let img = NSImage(size: NSSize(width: b, height: b), flipped: false) { _ in
            let p = NSBezierPath()
            for (i, (x, y)) in pts.enumerated() {
                let pt = NSPoint(x: b * (0.15 + 0.7 * x), y: b * (1 - (0.08 + 0.84 * y)))
                i == 0 ? p.move(to: pt) : p.line(to: pt)
            }
            p.close()
            let glow = NSShadow()
            glow.shadowColor = NSColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 1)
            glow.shadowBlurRadius = b * 0.10
            glow.set()
            NSColor(red: 0.96, green: 0.98, blue: 1.0, alpha: 1).setFill()
            p.fill()
            return true
        }
        var rect = NSRect(x: 0, y: 0, width: b * 2, height: b * 2)
        return img.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}

// MARK: - กราฟเส้นเทรนด์ความกดอากาศ 24 ชม.

struct PressureSparkline: View {
    let points: [PressurePoint]
    private static let line = Color(red: 0.35, green: 0.85, blue: 0.70)

    /// เปลี่ยนไปเท่าไรใน 3 ชม.ล่าสุด (เกณฑ์ barometric tendency ของ WMO ใช้ช่วง 3 ชม.)
    private var change3h: Double? {
        guard let last = points.last else { return nil }
        let target = last.time.addingTimeInterval(-3 * 3600)
        guard let ref = points.min(by: { abs($0.time.timeIntervalSince(target)) < abs($1.time.timeIntervalSince(target)) }),
              abs(ref.time.timeIntervalSince(target)) < 3600 else { return nil }
        return last.hPa - ref.hPa
    }

    private var trendText: (String, Color) {
        guard let d = change3h else { return ("-", .white.opacity(0.5)) }
        let v = String(format: "%+.1f hPa/3h", d)
        if d >= 1.6 { return ("⇈ \(v)", Color(red: 0.95, green: 0.55, blue: 0.35)) }
        if d >= 0.5 { return ("↗ \(v)", .white) }
        if d <= -1.6 { return ("⇊ \(v)", Color(red: 0.40, green: 0.70, blue: 1.0)) }
        if d <= -0.5 { return ("↘ \(v)", .white) }
        return ("→ \(v)", .white.opacity(0.75))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("PRESSURE 24H")
                    .font(.system(size: 9, weight: .semibold))
                    .kerning(1)
                    .foregroundStyle(.white.opacity(0.45))
                if let lo = points.map(\.hPa).min(), let hi = points.map(\.hPa).max() {
                    Text(String(format: "%.0f–%.0f", lo, hi))
                        .font(.system(size: 9))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.35))
                }
                Spacer()
                let (text, color) = trendText
                Text(text)
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            chart.frame(height: 30)
        }
    }

    private var chart: some View {
        GeometryReader { geo in
            if points.count >= 2, let t0 = points.first?.time, let t1 = points.last?.time, t1 > t0 {
                let vals = points.map(\.hPa)
                let lo = vals.min()!, hi = vals.max()!
                let span = max(hi - lo, 1.0)            // อย่างน้อย 1 hPa เต็มความสูง กันเส้นแกว่งเกินจริง
                let mid = (hi + lo) / 2
                let w = geo.size.width, h = geo.size.height
                let pts = points.map { p in
                    CGPoint(x: w * p.time.timeIntervalSince(t0) / t1.timeIntervalSince(t0),
                            y: h / 2 - (p.hPa - mid) / span * (h - 6))
                }
                let line = Path { path in
                    path.move(to: pts[0])
                    pts.dropFirst().forEach { path.addLine(to: $0) }
                }
                ZStack(alignment: .topLeading) {
                    Path { path in
                        path.addPath(line)
                        path.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        path.addLine(to: CGPoint(x: pts[0].x, y: h))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Self.line.opacity(0.30), Self.line.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    line.stroke(Self.line, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    Circle()
                        .fill(Self.line)
                        .frame(width: 5, height: 5)
                        .shadow(color: Self.line.opacity(0.8), radius: 3)
                        .position(pts.last!)
                }
            } else {
                Text("ยังไม่มีข้อมูลย้อนหลัง")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}


// MARK: - ถุงลม (windsock) 5 ระดับ

/// ถุงลมลายแดง-ขาวแบบสนามบิน ยิ่งลมแรงยิ่งกางตรง
/// ระดับตามความเร็วลม (กม./ชม.): <5.5 (ห้อยดิ่ง) • 5.5–11 • 11–16 • 16–22 • ≥22 (กางเต็มที่ 28 ขึ้นไป)
struct Windsock: View {
    let speed: Double?

    static func level(_ kmh: Double?) -> Int {
        guard let v = kmh else { return 1 }
        switch v {
        case ..<5.5: return 1
        case ..<11:  return 2
        case ..<16:  return 3
        case ..<22:  return 4
        default:     return 5
        }
    }

    private static let red = Color(red: 0.93, green: 0.27, blue: 0.10)
    private static let redDark = Color(red: 0.70, green: 0.17, blue: 0.06)
    private static let white = Color(red: 0.96, green: 0.96, blue: 0.97)

    var body: some View {
        Canvas { ctx, size in
            let lv = Self.level(speed)
            // มุมก้มของปล้องแรก และที่ก้มเพิ่มทีละปล้อง (องศา, ลงล่างเป็นบวก)
            // ระดับ 1 (ลมแทบไม่มี) ห้อยดิ่งขนานเสา
            let (a0, bend): (Double, Double) = [(90, 0), (9, 11), (5, 7), (2, 3.5), (1, 0.5)][lv - 1]
            let s = size.height / 30
            let poleX = 2.5 * s
            // ห้อยดิ่ง: ขยับปากถุงออกจากเสาไม่ให้ทับกัน และย่อปล้องให้พอดีความสูงหัวการ์ด
            let mouth = CGPoint(x: poleX + (lv == 1 ? 7 : 4.5) * s, y: 6.5 * s)
            let segLen = (lv == 1 ? 4.4 : 6.8) * s
            let widths: [Double] = [4.6, 4.0, 3.4, 2.8, 2.3, 1.9].map { $0 * s }    // ครึ่งความกว้างที่รอยต่อ

            // จุดกึ่งกลางรอยต่อ + ทิศของแต่ละปล้อง
            var pts = [mouth]
            var angles: [Double] = []
            for i in 0..<5 {
                let a = (a0 + bend * Double(i)) * .pi / 180
                angles.append(a)
                pts.append(CGPoint(x: pts[i].x + cos(a) * segLen, y: pts[i].y + sin(a) * segLen))
            }
            // แนวตั้งฉากที่รอยต่อใช้มุมเฉลี่ยของสองปล้อง — ไม่ให้มีร่องระหว่างปล้อง
            func normal(_ j: Int) -> CGVector {
                let a = j == 0 ? angles[0] : j == 5 ? angles[4] : (angles[j - 1] + angles[j]) / 2
                return CGVector(dx: -sin(a), dy: cos(a))
            }

            // เสา
            var pole = Path()
            pole.move(to: CGPoint(x: poleX, y: 3 * s))
            pole.addLine(to: CGPoint(x: poleX, y: size.height))
            ctx.stroke(pole, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: poleX - 1.4 * s, y: 2 * s, width: 2.8 * s, height: 2.8 * s)),
                     with: .color(.white.opacity(0.9)))
            // ลวดยึดจากหัวเสาไปขอบปากถุง
            let n0 = normal(0)
            var wire = Path()
            for side in [1.0, -1.0] {
                wire.move(to: CGPoint(x: poleX, y: 3.4 * s))
                wire.addLine(to: CGPoint(x: mouth.x + n0.dx * widths[0] * side, y: mouth.y + n0.dy * widths[0] * side))
            }
            ctx.stroke(wire, with: .color(Self.red.opacity(0.9)), lineWidth: 0.7 * s)

            // ปล้องสลับแดง/ขาว
            for i in 0..<5 {
                let na = normal(i), nb = normal(i + 1)
                var seg = Path()
                seg.move(to: CGPoint(x: pts[i].x + na.dx * widths[i], y: pts[i].y + na.dy * widths[i]))
                seg.addLine(to: CGPoint(x: pts[i + 1].x + nb.dx * widths[i + 1], y: pts[i + 1].y + nb.dy * widths[i + 1]))
                seg.addLine(to: CGPoint(x: pts[i + 1].x - nb.dx * widths[i + 1], y: pts[i + 1].y - nb.dy * widths[i + 1]))
                seg.addLine(to: CGPoint(x: pts[i].x - na.dx * widths[i], y: pts[i].y - na.dy * widths[i]))
                seg.closeSubpath()
                ctx.fill(seg, with: .color(i % 2 == 0 ? Self.red : Self.white))
            }
            // ปากถุง (วงรีเข้มมองเห็นด้านใน)
            var mouthCtx = ctx
            mouthCtx.translateBy(x: mouth.x, y: mouth.y)
            mouthCtx.rotate(by: .radians(angles[0]))
            mouthCtx.fill(Path(ellipseIn: CGRect(x: -1.5 * s, y: -widths[0], width: 3 * s, height: widths[0] * 2)),
                          with: .color(Self.redDark))
        }
        .frame(width: 44, height: 30)
        .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
        .help("ถุงลมระดับ \(Self.level(speed))/5")
    }
}
