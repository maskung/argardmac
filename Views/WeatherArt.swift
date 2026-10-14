import SwiftUI
import CoreImage

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

/// เมฆฟู 3D: ฐานโค้ง + ก้อนกลมหลายขนาด วาดจากหลังมาหน้า แต่ละก้อนไล่แสงจากซ้ายบน
/// ไล่แสงยาว + เบลอขอบเล็กน้อย ให้นุ่มฟุ้งแบบภาพอ้างอิง (รุ่นแรกเป็นก้อนกลมมันวาวเกินไป)
/// สูง 0.62 เท่าของความกว้าง
struct RealisticCloud: View {
    let tone: CloudTone
    let width: CGFloat

    var body: some View {
        let w = width
        let c = tone.colors
        func lit(_ r: CGFloat) -> RadialGradient {
            // สว่างกว้างขึ้น (c0 → c1 ยาว) แล้วค่อยมืดที่ขอบ — ลดความมันวาว
            RadialGradient(stops: [.init(color: c[0], location: 0), .init(color: c[1], location: 0.55),
                                   .init(color: c[2], location: 1)],
                           center: UnitPoint(x: 0.38, y: 0.30), startRadius: 0, endRadius: r * 1.45)
        }
        func puff(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> some View {
            Circle()
                .fill(lit(w * r))
                .frame(width: w * r * 2, height: w * r * 2)
                .shadow(color: .black.opacity(tone == .dark ? 0.28 : 0.10), radius: w * 0.02, y: w * 0.008)
                .position(x: w * x, y: w * y)
        }
        return ZStack {
            // ฐานเมฆ — เรียบ แบนด้านล่าง
            RoundedRectangle(cornerRadius: w * 0.12, style: .continuous)
                .fill(LinearGradient(colors: [c[1], c[2]], startPoint: .top, endPoint: .bottom))
                .frame(width: w * 0.84, height: w * 0.24)
                .position(x: w * 0.50, y: w * 0.48)
            puff(0.80, 0.45, 0.11)      // ขอบขวาล่าง
            puff(0.70, 0.36, 0.17)      // ขวาหลัง
            puff(0.62, 0.24, 0.14)      // ยอดขวา
            puff(0.18, 0.47, 0.10)      // ขอบซ้ายล่าง
            puff(0.28, 0.40, 0.15)      // ซ้าย
            puff(0.46, 0.27, 0.22)      // ก้อนใหญ่กลาง
            puff(0.38, 0.42, 0.14)      // ก้อนหน้า-ซ้ายล่าง
            puff(0.58, 0.43, 0.13)      // ก้อนหน้า-ขวาล่าง
            // ไฮไลต์ฟุ้งตามยอดก้อน ให้ดูเป็นไอน้ำนุ่ม ๆ
            Circle().fill(c[0].opacity(0.55)).frame(width: w * 0.20, height: w * 0.14)
                .blur(radius: w * 0.03).position(x: w * 0.42, y: w * 0.17)
            Circle().fill(c[0].opacity(0.40)).frame(width: w * 0.14, height: w * 0.10)
                .blur(radius: w * 0.025).position(x: w * 0.25, y: w * 0.33)
            // เงาด้านล่างของทั้งก้อน ให้ดูมีน้ำหนัก
            RoundedRectangle(cornerRadius: w * 0.12, style: .continuous)
                .fill(LinearGradient(colors: [.clear, c[2].opacity(0.55)], startPoint: .top, endPoint: .bottom))
                .frame(width: w * 0.84, height: w * 0.16)
                .position(x: w * 0.50, y: w * 0.52)
                .blendMode(.multiply)
        }
        .frame(width: w, height: w * 0.62)
        .compositingGroup()
        .blur(radius: w * 0.006)        // ขอบนุ่ม
        .shadow(color: .black.opacity(0.32), radius: w * 0.07, y: w * 0.04)
    }
}

/// จันทร์เสี้ยวเรืองแสง (ใช้รูปเสี้ยวจาก MoonLitShape ตัวเดียวกับจานจันทร์) + ดาวระยิบ
struct RealisticMoon: View {
    let diameter: CGFloat
    var stars = true

    var body: some View {
        let d = diameter
        ZStack {
            if stars {
                ForEach(0..<4, id: \.self) { i in
                    let p: [(CGFloat, CGFloat, CGFloat)] = [(-0.62, -0.42, 0.10), (0.66, -0.30, 0.07),
                                                             (0.52, 0.55, 0.06), (-0.70, 0.40, 0.05)]
                    Sparkle()
                        .fill(Color(red: 1.0, green: 0.97, blue: 0.85))
                        .frame(width: d * p[i].2 * 2, height: d * p[i].2 * 2)
                        .shadow(color: .white.opacity(0.8), radius: d * 0.03)
                        .offset(x: d * p[i].0, y: d * p[i].1)
                }
            }
            // แสงเรืองอยู่ฝั่งเสี้ยว (ขวา) — กลางวงเป็นด้านมืด ถ้าเรืองตรงกลางจะดูเป็นวงทึบหมอง
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1.0, green: 0.86, blue: 0.45).opacity(0.22), .clear],
                                     center: .center, startRadius: d * 0.1, endRadius: d * 0.6))
                .frame(width: d * 1.2, height: d * 1.2)
                .offset(x: d * 0.22)
            MoonLitShape(phase: 0.15)   // เสี้ยวข้างขึ้น
                .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.97, blue: 0.80),
                                              Color(red: 0.98, green: 0.78, blue: 0.30)],
                                     startPoint: .topTrailing, endPoint: .bottomLeading))
                .frame(width: d, height: d)
                .rotationEffect(.degrees(-18))
                .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.2).opacity(0.7), radius: d * 0.08)
        }
    }
}

/// ดาวสี่แฉก
struct Sparkle: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY), a = r.width / 2, b = r.width * 0.12
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - a))
        p.addQuadCurve(to: CGPoint(x: c.x + a, y: c.y), control: CGPoint(x: c.x + b, y: c.y - b))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + a), control: CGPoint(x: c.x + b, y: c.y + b))
        p.addQuadCurve(to: CGPoint(x: c.x - a, y: c.y), control: CGPoint(x: c.x - b, y: c.y + b))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - a), control: CGPoint(x: c.x - b, y: c.y - b))
        return p
    }
}

/// หมอก: แถบไอโปร่งแสงเบลอ 4 ชั้น ลอยเลื่อนซ้าย-ขวาช้า ๆ สลับทิศกัน
/// ใช้ Core Animation: เบลอแถบเป็นภาพครั้งเดียว แล้วให้ render server เลื่อนภาพ
/// (รุ่นแรกใช้ SwiftUI repeatForever + blur — ต้องเบลอใหม่ทุกเฟรม CPU ขึ้นถึง 42%)
struct RealisticFog: NSViewRepresentable {
    let width: CGFloat

    func makeNSView(context: Context) -> FogNSView { FogNSView(width: width) }
    func updateNSView(_ view: FogNSView, context: Context) {}
}

final class FogNSView: NSView {
    private let width: CGFloat
    /// (ตำแหน่ง y จากกลาง ×ความกว้าง, ความยาว ×ความกว้าง, ความทึบ, ทิศเลื่อน)
    private let bands: [(y: CGFloat, len: CGFloat, op: CGFloat, dir: CGFloat)] = [
        (-0.30, 0.80, 0.55, 1), (-0.10, 0.95, 0.75, -1), (0.10, 0.85, 0.65, 1), (0.30, 0.70, 0.45, -1),
    ]
    private var bandLayers: [CALayer] = []

    init(width: CGFloat) {
        self.width = width
        super.init(frame: .zero)
        wantsLayer = true
        for b in bands {
            let l = CALayer()
            l.contents = Self.bandImage(length: width * b.len, thickness: width * 0.13,
                                        blur: width * 0.035, opacity: b.op)
            l.contentsGravity = .resize
            layer?.addSublayer(l)
            bandLayers.append(l)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        guard w > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let pad = width * 0.035 * 3                       // ขอบเผื่อให้ความเบลอ
        for (b, l) in zip(bands, bandLayers) {
            l.bounds = CGRect(x: 0, y: 0, width: width * b.len + pad * 2, height: width * 0.13 + pad * 2)
            // เลเยอร์นับ y จากล่างขึ้นบน — b.y เป็นบวก = ต่ำกว่ากลาง
            let center = CGPoint(x: w / 2, y: h / 2 - width * b.y)
            l.position = center
            l.contentsScale = window?.backingScaleFactor ?? 2
            let a = CABasicAnimation(keyPath: "position.x")
            a.fromValue = center.x - width * 0.06 * b.dir
            a.toValue = center.x + width * 0.06 * b.dir
            a.duration = 5
            a.autoreverses = true
            a.repeatCount = .infinity
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            l.add(a, forKey: "drift")
        }
        CATransaction.commit()
    }

    /// แถบหมอก: แคปซูลขาวจางที่ปลายทั้งสองข้าง แล้วเบลอด้วย Core Image (ทำครั้งเดียว)
    private static func bandImage(length: CGFloat, thickness: CGFloat, blur: CGFloat, opacity: CGFloat) -> CGImage? {
        let scale: CGFloat = 2, pad = blur * 3
        let W = Int((length + pad * 2) * scale), H = Int((thickness + pad * 2) * scale)
        guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        let rect = CGRect(x: pad, y: pad, width: length, height: thickness)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: thickness / 2, cornerHeight: thickness / 2, transform: nil))
        ctx.clip()
        let white = CGColor(red: 1, green: 1, blue: 1, alpha: opacity), clear = CGColor(red: 1, green: 1, blue: 1, alpha: 0)
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [clear, white, white, clear] as CFArray,
                              locations: [0, 0.3, 0.7, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: rect.minX, y: 0), end: CGPoint(x: rect.maxX, y: 0), options: [])
        guard let sharp = ctx.makeImage() else { return nil }
        let ci = CIImage(cgImage: sharp).clampedToExtent()
            .applyingGaussianBlur(sigma: Double(blur * scale))
            .cropped(to: CGRect(x: 0, y: 0, width: W, height: H))
        return CIContext().createCGImage(ci, from: ci.extent)
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
    /// false = ภาพนิ่ง (ช่องพยากรณ์รายชั่วโมง): วาดเม็ดฝน/สายฟ้าค้างไว้ หมอกไม่ลอย
    /// true = ไอคอนกลาง Hero card: ฝน/ฟ้าแลบมาจาก RainNSView ที่ซ้อนอยู่ข้างหลัง
    var animated = true

    enum Kind { case sun, partly, cloudy, rain, storm, moon, partlyNight, fog }

    static func kind(for icon: String) -> Kind? {
        switch true {
        case icon.contains("11"): .storm
        case icon.contains("09"), icon.contains("10"): .rain
        case icon.contains("03"), icon.contains("04"): .cloudy
        case icon.contains("02"): icon.contains("d") ? .partly : .partlyNight
        case icon.contains("01"): icon.contains("d") ? .sun : .moon
        case icon.contains("50"): .fog
        default: nil                    // หิมะ — ยังใช้ emoji เดิม
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
                if !animated { StaticRain(size: size, bolt: false).frame(width: w, height: h) }
                RealisticCloud(tone: .grey, width: size * 1.0)
                    .position(x: w / 2, y: h * 0.36)
            case .storm:
                if !animated { StaticRain(size: size, bolt: true).frame(width: w, height: h) }
                RealisticCloud(tone: .dark, width: size * 1.0)
                    .position(x: w / 2, y: h * 0.36)
            case .moon:
                RealisticMoon(diameter: size * 0.62)
                    .position(x: w / 2, y: h / 2)
            case .partlyNight:
                RealisticMoon(diameter: size * 0.50, stars: false)
                    .position(x: w * 0.38, y: h * 0.34)
                RealisticCloud(tone: .grey, width: size * 0.92)
                    .position(x: w * 0.57, y: h * 0.62)
            case .fog:
                if animated {
                    RealisticFog(width: size * 1.05)
                        .frame(width: w, height: h)
                } else {
                    StaticFog(width: size * 1.05)
                        .position(x: w / 2, y: h / 2)
                }
            case nil:
                EmptyView()
            }
        }
        .frame(width: w, height: h)
    }
}

/// ฝนแบบภาพนิ่งใต้เมฆ (ช่องพยากรณ์รายชั่วโมง) — เม็ดเอียงสั้น ๆ + สายฟ้าสำหรับพายุ
/// กรอบเดียวกับ RealisticWeatherIcon (size×1.25 กว้าง, size×1.2 สูง)
struct StaticRain: View {
    let size: CGFloat
    let bolt: Bool

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height, len = size * 0.14
            // ตำแหน่งเม็ด (x, y) วัดจากซ้ายบนของกรอบ เป็นสัดส่วน
            let drops: [(CGFloat, CGFloat)] = [(0.30, 0.66), (0.44, 0.74), (0.58, 0.64), (0.70, 0.76),
                                               (0.36, 0.86), (0.64, 0.88)]
            for (x, y) in drops where !(bolt && abs(x - 0.5) < 0.1) {
                var p = Path()
                p.move(to: CGPoint(x: w * x, y: h * y))
                p.addLine(to: CGPoint(x: w * x - len * 0.3, y: h * y + len))
                ctx.stroke(p, with: .color(Color(red: 0.55, green: 0.78, blue: 1.0)),
                           style: StrokeStyle(lineWidth: max(1.2, size * 0.045), lineCap: .round))
            }
            if bolt {
                // จุดยอดสายฟ้าเดียวกับ RainNSView.boltImage (วัดจากขอบบนของกรอบสายฟ้า)
                let pts: [(CGFloat, CGFloat)] = [(0.58, 0.00), (0.30, 0.50), (0.47, 0.50), (0.32, 1.00),
                                                (0.72, 0.40), (0.54, 0.40), (0.70, 0.00)]
                let b = size * 0.42, ox = w * 0.5 - b / 2, oy = h * 0.58
                var p = Path()
                for (i, (x, y)) in pts.enumerated() {
                    let pt = CGPoint(x: ox + b * x, y: oy + b * y)
                    i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                }
                p.closeSubpath()
                var glow = ctx
                glow.addFilter(.shadow(color: Color(red: 0.45, green: 0.65, blue: 1.0), radius: size * 0.06))
                glow.fill(p, with: .color(Color(red: 0.96, green: 0.98, blue: 1.0)))
            }
        }
    }
}

/// หมอกแบบภาพนิ่ง: แถบไอเบลอ 4 ชั้นวางเหลื่อมกัน (แบบเดียวกับหมอกลอยใน Hero card)
struct StaticFog: View {
    let width: CGFloat

    var body: some View {
        let w = width
        let bands: [(y: CGFloat, len: CGFloat, op: Double, dx: CGFloat)] = [
            (-0.30, 0.80, 0.55, 0.05), (-0.10, 0.95, 0.75, -0.04), (0.10, 0.85, 0.65, 0.04), (0.30, 0.70, 0.45, -0.05),
        ]
        ZStack {
            ForEach(0..<bands.count, id: \.self) { i in
                let b = bands[i]
                Capsule()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(b.op), .white.opacity(b.op), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: w * b.len, height: w * 0.13)
                    .blur(radius: w * 0.03)
                    .offset(x: w * b.dx, y: w * b.y)
            }
        }
        .frame(width: w, height: w * 0.8)
    }
}
