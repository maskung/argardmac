import SwiftUI

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
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - หยดน้ำวัดความชื้น (น้ำเติมตามระดับ %)

struct DropShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w / 2, y: 0))
        // ลงด้านขวาไปก้นหยด
        p.addCurve(to: CGPoint(x: w / 2, y: h),
                   control1: CGPoint(x: w, y: h * 0.28),
                   control2: CGPoint(x: w, y: h * 0.72))
        // กลับขึ้นด้านซ้าย
        p.addCurve(to: CGPoint(x: w / 2, y: 0),
                   control1: CGPoint(x: 0, y: h * 0.72),
                   control2: CGPoint(x: 0, y: h * 0.28))
        p.closeSubpath()
        return p
    }
}

struct DropGauge: View {
    let ratio: Double              // 0...1
    private var clamped: CGFloat { CGFloat(min(max(ratio, 0), 1)) }

    var body: some View {
        ZStack {
            // ตัวหยดเปล่า
            DropShape().fill(.white.opacity(0.07))
            // น้ำภายใน — สูงตาม ratio ชิดก้น
            DropShape()
                .fill(Theme.water)
                .mask(GeometryReader { geo in
                    Rectangle()
                        .frame(height: geo.size.height * clamped)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                })
            // เส้นผิวน้ำ
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.85))
                    .frame(height: 3)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .offset(y: -geo.size.height * clamped)
            }
            .mask(DropShape())
            .opacity(clamped > 0.03 ? 1 : 0)
            // ขอบหยด
            DropShape().stroke(.white.opacity(0.35), lineWidth: 1.5)
        }
        .animation(.easeInOut(duration: 0.7), value: clamped)
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
