import SwiftUI

/// หน้าเรดาร์ฝนเต็มจอ: แผนที่ใหญ่เล่นย้อนหลัง 2 ชม. + คาดการณ์ 1 ชม. และแผงสรุปว่าฝนจะถึงสวนเมื่อไร
struct RainRadarView: View {
    @ObservedObject var store: WeatherStore
    @State private var playing = true
    @State private var manualIndex = 0
    @AppStorage("radar.zoomKm") private var zoomKm = 100.0     // จำระยะซูมที่เลือกไว้

    private static let tick = 0.45          // วินาทีต่อเฟรม
    private static let holdTicks = 4        // ค้างเฟรมสุดท้ายก่อนวนใหม่
    private let sidebarWidth: CGFloat = 330

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("RAIN RADAR • NOWCAST 0–2 HOURS")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(Theme.textGold)
                Spacer()
                Text("เรดาร์: RainViewer.com • แผนที่: © Esri")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
            }
            GeometryReader { geo in
                let side = max(200, min(geo.size.height - 44, geo.size.width - sidebarWidth - 16))
                HStack(alignment: .top, spacing: 16) {
                    mapPanel(side: side)
                    ScrollView { sidebar }
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
    }

    // MARK: - แผนที่

    @ViewBuilder private func mapPanel(side: CGFloat) -> some View {
        if let snap = store.radar {
            let frames = snap.frames + snap.forecast
            TimelineView(.periodic(from: .now, by: Self.tick)) { ctx in
                let n = frames.count
                let auto = min(Int(ctx.date.timeIntervalSinceReferenceDate / Self.tick) % (n + Self.holdTicks), n - 1)
                let idx = playing ? auto : min(manualIndex, n - 1)
                VStack(spacing: 10) {
                    RadarBigMap(snapshot: snap, frame: frames[idx], zoomKm: zoomKm)
                        .frame(width: side, height: side)
                    controls(frames: frames, index: idx, latestPast: snap.frames.count - 1)
                        .frame(width: side)
                }
            }
        } else {
            VStack(spacing: 10) {
                if store.radarError.isEmpty {
                    ProgressView()
                    Text("กำลังโหลดภาพเรดาร์…").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                } else {
                    Text("ดึงภาพเรดาร์ไม่ได้: \(store.radarError)")
                        .font(.system(size: 12)).foregroundStyle(.orange)
                }
            }
            .frame(width: side, height: side)
            .glassCard(corner: 14)
        }
    }

    private func controls(frames: [RadarFrame], index: Int, latestPast: Int) -> some View {
        HStack(spacing: 12) {
            Button {
                if playing { manualIndex = index }
                playing.toggle()
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .frame(width: 18)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.space, modifiers: [])

            Slider(value: Binding(
                get: { Double(index) },
                set: { playing = false; manualIndex = Int($0.rounded()) }),
                   in: 0...Double(max(frames.count - 1, 1)), step: 1)

            Button("ล่าสุด") { playing = false; manualIndex = latestPast }
                .buttonStyle(.bordered)

            Picker("", selection: $zoomKm) {
                Text("50 กม.").tag(50.0)
                Text("100 กม.").tag(100.0)
                Text("200 กม.").tag(200.0)
            }
            .pickerStyle(.segmented)
            .frame(width: 190)
        }
        .controlSize(.small)
    }

    // MARK: - แผงขวา

    /// จอกว้างจะเรียงเป็น 2 คอลัมน์เอง
    private var sidebar: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: sidebarWidth), spacing: 12, alignment: .top)],
                  alignment: .leading, spacing: 12) {
            statusCard
            outlookCard
            detailCard
            modelCard
            legendCard
        }
    }

    private var statusCard: some View {
        let c = store.radar?.nowcast
        return Card(title: "Rain at Garden", systemIcon: "location.circle", accent: Theme.rain,
                    badge: c.map { $0.frameTime.formatted(.dateTime.hour().minute()) }, minHeight: 0) {
            if let c {
                Text(c.headline(sensorRate: store.obs.metric.precipRate))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Self.statusColor(c.status))
                    .fixedSize(horizontal: false, vertical: true)
                if let d = c.detail {
                    Text(d).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                }
                let lag = Int(Date().timeIntervalSince(c.frameTime) / 60)
                Text("ภาพเรดาร์ล่าสุด \(c.frameTime.formatted(.dateTime.hour().minute())) — ช้ากว่าเวลาจริง ~\(lag) นาที")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                Text("รอภาพเรดาร์…").foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private var outlookCard: some View {
        Card(title: "Next 2 Hours at Garden", systemIcon: "chart.bar.xaxis", accent: Theme.water, minHeight: 0) {
            if let c = store.radar?.nowcast, !c.outlook.isEmpty {
                OutlookBars(points: c.outlook)
                    .frame(height: 90)
                Text("ความแรงฝนที่คาดว่าจะผ่านสวน ทุก 5 นาที นับจากตอนนี้ (เลื่อนภาพเรดาร์ล่าสุดตามทิศที่ฝนเคลื่อน)")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(store.radar?.nowcast?.status == .clear
                     ? "ไม่มีฝนในพื้นที่ — ยังไม่มีอะไรให้ทำนาย"
                     : "ยังหาทิศการเคลื่อนของฝนไม่ได้ (ฝนน้อยเกินไป หรือก่อตัวอยู่กับที่) — ดูจากแผนที่แทน")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var detailCard: some View {
        let c = store.radar?.nowcast
        let m = store.obs.metric
        return Card(title: "Details", systemIcon: "list.bullet", accent: Theme.violet, minHeight: 0) {
            InfoRow("📍 ฝนที่ใกล้สุด", c?.nearestKm.map { km in
                String(format: "%.0f กม. %@", km, c?.nearestBearing.map { "ทาง" + RadarNowcast.thaiCompass($0) } ?? "")
            } ?? "-")
            InfoRow("🧭 ทิศที่ฝนเคลื่อน", {
                guard let c, let v = c.motionKmh, let from = c.motionFromDeg else { return "-" }
                return v < 3 ? "แทบไม่เคลื่อนที่" : String(format: "จาก%@ %.0f กม./ชม.", RadarNowcast.thaiCompass(from), v)
            }())
            InfoRow("🎯 รัศมีที่วิเคราะห์", c.map { String(format: "%.0f กม.", $0.rangeKm) } ?? "-")
            Divider().overlay(.white.opacity(0.12))
            InfoRow("🌧️ เซนเซอร์สวน (ตอนนี้)", WX.fmt(m.precipRate, 1, suffix: " mm/h"))
            InfoRow("📅 ฝนสะสมวันนี้", WX.fmt(m.precipTotal, 1, suffix: " mm"))
        }
    }

    /// เทียบกับโมเดลพยากรณ์ (ICON) — ใช้ดูช่วงเกิน 2 ชม. ที่เรดาร์ทำนายไม่ถึง
    private var modelCard: some View {
        Card(title: "Model Forecast (ICON)", systemIcon: "cloud.sun.rain", accent: Theme.gold, minHeight: 0) {
            ForEach(Array(store.forecast.prefix(6).enumerated()), id: \.offset) { _, h in
                HStack(spacing: 8) {
                    Text(Date(timeIntervalSince1970: h.dt).formatted(.dateTime.hour().minute()))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 44, alignment: .leading)
                    WeatherIconView(icon: h.weatherIcon, size: 16)
                    GaugeBar(value: (h.pop ?? 0) * 100, maxValue: 100,
                             tint: Color(red: 0.30, green: 0.62, blue: 1.0))
                    Text(WX.fmtInt((h.pop ?? 0) * 100, suffix: "%"))
                        .monospacedDigit()
                        .frame(width: 38, alignment: .trailing)
                    Text(WX.fmt(h.rain ?? 0, 1, suffix: " mm"))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity((h.rain ?? 0) > 0 ? 0.9 : 0.4))
                        .frame(width: 52, alignment: .trailing)
                }
                .font(.system(size: 12))
            }
        }
    }

    private var legendCard: some View {
        Card(title: "Radar Scale", systemIcon: "paintpalette", accent: Theme.breeze, minHeight: 0) {
            RadarLegend()
        }
    }

    static func statusColor(_ s: RadarNowcast.Status) -> Color {
        switch s {
        case .raining: return Color(red: 0.40, green: 0.75, blue: 1.0)
        case .approaching: return .orange
        case .nearby: return .white.opacity(0.85)
        case .clear: return Color(red: 0.45, green: 0.85, blue: 0.55)
        }
    }
}

// MARK: - แผนที่ใหญ่

private struct RadarBigMap: View {
    let snapshot: RadarSnapshot
    let frame: RadarFrame
    let zoomKm: Double

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            let s = snapshot
            // ครึ่งความกว้างที่แสดง (พิกเซลเรดาร์) — ไม่เกินขอบภาพที่มี
            let maxHalf = min(s.garden.x, s.garden.y, CGFloat(s.size) - s.garden.x, CGFloat(s.size) - s.garden.y)
            let half = min(CGFloat(zoomKm / s.kmPerPixel), maxHalf)
            let k = side / (half * 2)                       // จุดบนจอต่อพิกเซลเรดาร์
            let full = CGFloat(s.size) * k
            let ox = -(s.garden.x - half) * k, oy = -(s.garden.y - half) * k
            let center = CGPoint(x: side / 2, y: side / 2)

            ZStack(alignment: .topLeading) {
                Color(red: 0.13, green: 0.14, blue: 0.16)
                // ซูมใกล้ (อยู่ในกรอบภาพละเอียด) ใช้ภาพที่เกลี่ยขอบแล้ว + แผนที่ซูม 9 / ไกลใช้ภาพเต็มเดิม
                let dh = CGFloat(RainRadarService.detailHalf)
                let useDetail = half <= dh && frame.detail != nil
                let d0 = CGFloat(s.size) / 2 - dh                  // มุมซ้ายบนของภาพละเอียด (พิกเซลเรดาร์)
                let dx = (d0 - (s.garden.x - half)) * k, dy = (d0 - (s.garden.y - half)) * k
                if useDetail, let base = s.detailBasemap {
                    layer(base, x: dx, y: dy, side: dh * 2 * k, interpolation: .high)
                } else if let base = s.basemap {
                    layer(base, x: ox, y: oy, side: full, interpolation: .high)
                }
                Group {
                    if useDetail, let img = frame.detail {
                        layer(img, x: dx, y: dy, side: dh * 2 * k, interpolation: .medium)
                    } else {
                        layer(frame.image, x: ox, y: oy, side: full, interpolation: .medium)
                    }
                }
                .opacity(frame.isForecast ? 0.7 : 0.85)
                if useDetail, let labels = s.detailLabels {
                    layer(labels, x: dx, y: dy, side: dh * 2 * k, interpolation: .high)
                }

                rings(center: center, pxPerKm: k / CGFloat(s.kmPerPixel), side: side)
                if let v = s.nowcast?.motionVector {
                    MotionArrow(from: center, to: CGPoint(x: center.x + v.dx * 30 * k, y: center.y + v.dy * 30 * k))
                }
                gardenMarker.position(center)
                frameLabel.padding(10)
            }
            .frame(width: side, height: side, alignment: .topLeading)    // ภาพใหญ่กว่ากรอบ — ยึดมุมซ้ายบน ไม่ให้ถูกจัดกลาง
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(frame.isForecast ? Color.orange.opacity(0.7) : .white.opacity(0.12),
                          style: StrokeStyle(lineWidth: frame.isForecast ? 2 : 1, dash: frame.isForecast ? [6, 4] : [])))
    }

    private func layer(_ img: CGImage, x: CGFloat, y: CGFloat, side: CGFloat,
                       interpolation: Image.Interpolation) -> some View {
        Image(decorative: img, scale: 1)
            .resizable()
            .interpolation(interpolation)
            .frame(width: side, height: side)
            .offset(x: x, y: y)
    }

    private func rings(center: CGPoint, pxPerKm: CGFloat, side: CGFloat) -> some View {
        ForEach([10.0, 25.0, 50.0, 100.0, 200.0], id: \.self) { km in
            let r = CGFloat(km) * pxPerKm
            if r > 18, r < side * 0.75 {
                Circle()
                    .strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                    .frame(width: r * 2, height: r * 2)
                    .position(center)
                Text("\(Int(km)) กม.")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .position(x: center.x, y: center.y - r - 7)
            }
        }
    }

    private var gardenMarker: some View {
        ZStack {
            Circle().fill(.red.opacity(0.25)).frame(width: 22, height: 22)
            Circle().stroke(.red, lineWidth: 2).frame(width: 12, height: 12)
            Circle().fill(.white).frame(width: 5, height: 5)
        }
        .shadow(color: .black.opacity(0.6), radius: 3)
    }

    private var frameLabel: some View {
        let now = Date()
        let mins = Int((frame.time.timeIntervalSince(now) / 60).rounded())
        let text = frame.isForecast
            ? "คาดการณ์ \(frame.time.formatted(.dateTime.hour().minute())) (\(mins >= 0 ? "อีก \(mins) นาที" : "\(-mins) นาทีก่อน"))"
            : "\(frame.time.formatted(.dateTime.hour().minute())) • \(-mins) นาทีก่อน"
        return HStack(spacing: 6) {
            Image(systemName: frame.isForecast ? "wand.and.stars" : "dot.radiowaves.left.and.right")
            Text(text).monospacedDigit()
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(frame.isForecast ? .orange : .white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.black.opacity(0.55), in: Capsule())
    }
}

/// ลูกศรทิศที่กลุ่มฝนเคลื่อนไป ยาวเท่าระยะที่ฝนเดินใน 30 นาที
private struct MotionArrow: View {
    let from: CGPoint
    let to: CGPoint

    var body: some View {
        let dx = to.x - from.x, dy = to.y - from.y
        let len = (dx * dx + dy * dy).squareRoot()
        if len > 12 {
            let ux = dx / len, uy = dy / len
            let head: CGFloat = 9
            ZStack {
                Path { p in
                    p.move(to: from)
                    p.addLine(to: to)
                }
                .stroke(Color.yellow.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                Path { p in
                    p.move(to: to)
                    p.addLine(to: CGPoint(x: to.x - head * ux + head * 0.6 * uy, y: to.y - head * uy - head * 0.6 * ux))
                    p.addLine(to: CGPoint(x: to.x - head * ux - head * 0.6 * uy, y: to.y - head * uy + head * 0.6 * ux))
                    p.closeSubpath()
                }
                .fill(Color.yellow.opacity(0.9))
                Text("30 นาที")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.yellow)
                    .position(x: to.x + ux * 22, y: to.y + uy * 14)
            }
            .shadow(color: .black.opacity(0.7), radius: 2)
        }
    }
}

// MARK: - กราฟฝน 2 ชม. ข้างหน้าที่สวน

private struct OutlookBars: View {
    let points: [OutlookPoint]

    var body: some View {
        // ภาพเรดาร์ช้ากว่าเวลาจริง — ตัดช่วงที่ผ่านไปแล้วทิ้ง ให้แท่งแรก = ตอนนี้เสมอ
        let now = Date()
        let ahead = points.filter { $0.time.timeIntervalSince(now) > -150 }
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height - 14
            let bw = w / CGFloat(max(ahead.count, 1))
            ZStack(alignment: .topLeading) {
                Rectangle().fill(.white.opacity(0.15)).frame(width: w, height: 1).offset(y: h)
                ForEach(Array(ahead.enumerated()), id: \.offset) { i, p in
                    let v = max(0, min(65, p.dbz) - 10)
                    let bh = CGFloat(v) / 55 * h
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(p.dbz >= RainRadarService.rainDBZ ? Color(rgb: RainRadarService.color(dbz: p.dbz))
                                                                : .white.opacity(0.12))
                        .frame(width: max(bw - 2, 1), height: max(bh, 1))
                        .offset(x: CGFloat(i) * bw + 1, y: h - max(bh, 1))
                }
                if !ahead.contains(where: { $0.dbz >= RainRadarService.rainDBZ }) {
                    Text("☀️ ไม่มีฝนผ่านสวนในช่วงนี้")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: w, height: h)
                }
                // ป้ายเวลาเทียบกับตอนนี้: ตอนนี้ / +30 / +60 / +90 นาที
                ForEach([0, 30, 60, 90], id: \.self) { m in
                    let i = m / 5
                    if i < ahead.count {
                        Text(m == 0 ? "ตอนนี้" : "+\(m) นาที")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.45))
                            .fixedSize()
                            .position(x: min(max(CGFloat(i) * bw + bw / 2, 16), w - 22), y: h + 8)
                    }
                }
            }
        }
    }
}

private struct RadarLegend: View {
    private let stops: [(dbz: Int, label: String)] = [(20, "เบา"), (30, "ปานกลาง"), (40, "หนัก"), (50, "หนักมาก"), (58, "พายุ")]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                ForEach(15..<66, id: \.self) { d in
                    Rectangle().fill(Color(rgb: RainRadarService.color(dbz: d)))
                }
            }
            .frame(height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            GeometryReader { geo in
                ForEach(stops, id: \.dbz) { s in
                    Text(s.label)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize()
                        .position(x: geo.size.width * CGFloat(s.dbz - 15) / 51 + 12, y: 6)
                }
            }
            .frame(height: 12)
            Text("ฟ้า = ฝนเบา–ปานกลาง • เหลือง/ส้ม = หนัก • แดง = หนักมาก • ชมพู = พายุฝนฟ้าคะนองรุนแรง")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension Color {
    init(rgb: UInt32) {
        self.init(red: Double(rgb >> 16 & 255) / 255, green: Double(rgb >> 8 & 255) / 255, blue: Double(rgb & 255) / 255)
    }
}
