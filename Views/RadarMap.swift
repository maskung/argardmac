import SwiftUI
import AppKit

/// แผนที่เรดาร์ขนาดเล็ก: แผนที่ฐาน + ภาพฝนย้อนหลัง ~2 ชม. เล่นวน + จุดสวนและวงรัศมี 25/50 กม.
struct RadarMiniMap: View {
    let snapshot: RadarSnapshot?
    /// แสดงเฉพาะกลางภาพ ±viewRadius พิกเซล (~±95 กม.) — ภาพเต็มกว้างเกินสำหรับการ์ดเล็ก
    var viewRadius = 80

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            ZStack(alignment: .topLeading) {
                Color(red: 0.13, green: 0.14, blue: 0.16)
                if let snap = snapshot {
                    let cut = CGFloat(snap.size / 2 - viewRadius)
                    RadarLoopView(snapshot: snap, visible: CGRect(x: cut / CGFloat(snap.size), y: cut / CGFloat(snap.size),
                                                                  width: CGFloat(2 * viewRadius) / CGFloat(snap.size),
                                                                  height: CGFloat(2 * viewRadius) / CGFloat(snap.size)))
                    let k = side / CGFloat(2 * viewRadius)
                    let g = CGPoint(x: (snap.garden.x - cut) * k, y: (snap.garden.y - cut) * k)
                    ForEach([25.0, 50.0], id: \.self) { km in
                        let r = km / snap.kmPerPixel * k
                        Circle()
                            .strokeBorder(.white.opacity(0.22), style: StrokeStyle(lineWidth: 0.6, dash: [2, 2]))
                            .frame(width: r * 2, height: r * 2)
                            .position(g)
                    }
                    Circle()
                        .fill(.white)
                        .frame(width: 5, height: 5)
                        .overlay(Circle().stroke(Color.red, lineWidth: 1.5).frame(width: 9, height: 9))
                        .position(g)
                    if let t = snap.frames.last?.time {
                        Text("RainViewer \(t.formatted(.dateTime.hour().minute()))")
                            .font(.system(size: 7.5, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 3)
                            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 3))
                            .padding(3)
                            .frame(width: side, height: side, alignment: .bottomTrailing)
                    }
                } else {
                    ProgressView().controlSize(.small)
                        .frame(width: side, height: side)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.12)))
    }
}

/// เล่นภาพเรดาร์วนด้วย Core Animation (สลับ contents) — ไม่ต้องให้ SwiftUI วาดใหม่ทุกเฟรม
private struct RadarLoopView: NSViewRepresentable {
    let snapshot: RadarSnapshot
    var visible = CGRect(x: 0, y: 0, width: 1, height: 1)     // ส่วนของภาพที่จะแสดง (หน่วย 0…1)

    func makeNSView(context: Context) -> RadarLayerView { RadarLayerView() }

    func updateNSView(_ v: RadarLayerView, context: Context) {
        // ตัดกลางภาพแบบสมมาตร — ไม่ต้องสนว่า contentsRect นับ y จากบนหรือล่าง
        v.base.contentsRect = visible
        v.radar.contentsRect = visible
        v.show(snapshot)
    }
}

private final class RadarLayerView: NSView {
    let base = CALayer()
    let radar = CALayer()
    private var key = ""

    override init(frame: NSRect) {
        super.init(frame: frame)
        // layer-hosting view (ตั้ง layer เองก่อน wantsLayer) — AppKit จะไม่ไปยุ่งกับ sublayer ของเรา
        layer = CALayer()
        wantsLayer = true
        for l in [base, radar] {
            l.contentsGravity = .resize
            layer?.addSublayer(l)
        }
        base.magnificationFilter = .linear
        radar.magnificationFilter = .nearest       // ให้เห็นเป็นช่องพิกเซลเรดาร์ชัด ๆ
        radar.opacity = 0.85
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        base.frame = bounds
        radar.frame = bounds
        CATransaction.commit()
    }

    /// SwiftUI เรียก update ทุกวินาที (heartbeat ของ Dashboard) — ตั้งแอนิเมชันใหม่เฉพาะตอนได้ภาพชุดใหม่
    func show(_ snapshot: RadarSnapshot) {
        let newKey = snapshot.frames.map { "\($0.time.timeIntervalSince1970)" }.joined(separator: ",")
            + (snapshot.basemap == nil ? "" : "+map")
        guard newKey != key else { return }
        key = newKey
        base.contents = snapshot.basemap
        let images = snapshot.frames.map(\.image)
        radar.removeAllAnimations()
        radar.contents = images.last
        guard images.count > 1 else { return }

        // ทุกเฟรม 0.35 วิ แล้วค้างเฟรมล่าสุด 1.5 วิ ก่อนวนใหม่
        let step = 0.35, hold = 1.5
        let total = step * Double(images.count - 1) + hold
        let anim = CAKeyframeAnimation(keyPath: "contents")
        anim.values = images
        anim.keyTimes = images.indices.map { NSNumber(value: step * Double($0) / total) }
        anim.calculationMode = .discrete
        anim.duration = total
        anim.repeatCount = .infinity
        anim.isRemovedOnCompletion = false
        radar.add(anim, forKey: "loop")
    }
}
