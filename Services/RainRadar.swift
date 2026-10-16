import Foundation
import CoreGraphics
import ImageIO

/// เรดาร์ฝนจาก RainViewer (ฟรี ไม่ต้องใช้ key — ขอให้ใส่เครดิต) + ทำนายระยะสั้นแบบ extrapolation
/// 1) ดึงภาพเรดาร์ย้อนหลัง ~2 ชม. (ทุก 10 นาที) รอบสวน ±240 กม. (วิเคราะห์เฉพาะ ±140 กม.)
/// 2) เทียบภาพที่ต่อกันหาทิศ/ความเร็วที่กลุ่มฝนเคลื่อน
/// 3) เลื่อนภาพล่าสุดไปข้างหน้าตามความเร็วนั้น แล้วดูว่าฝนจะถึงสวนเมื่อไร
/// ข้อจำกัด: ฝนที่ก่อตัวขึ้นใหม่กลางที่ (พายุบ่ายแถบร้อน) ทำนายล่วงหน้าไม่ได้
struct RadarFrame {
    let time: Date
    let image: CGImage          // ภาพสีของเรดาร์ (โปร่งใสตรงไม่มีฝน) ขนาด size × size
    let dbz: [UInt8]            // ค่า dBZ ต่อพิกเซล (0 = ไม่มีฝน/ต่ำกว่า 15) — ว่างในเฟรมคาดการณ์
    var isForecast = false
}

/// ความแรงฝนที่คาดว่าจะผ่านสวน ณ เวลาหนึ่ง (จากการเลื่อนภาพล่าสุด)
struct OutlookPoint: Equatable {
    let time: Date
    let dbz: Int
}

struct RadarNowcast: Equatable {
    enum Status: Equatable {
        case raining            // ฝนตกที่สวนอยู่ (ตามเรดาร์)
        case approaching        // มีฝนกำลังเคลื่อนเข้ามา (มี ETA)
        case nearby             // มีฝนในรัศมี แต่ไม่ได้มุ่งมาที่สวน / หาทิศไม่ได้
        case clear              // ไม่มีฝนในพื้นที่ภาพ
    }
    var status: Status
    var frameTime: Date
    var eta: Date?              // เวลาที่ฝนน่าจะถึงสวน
    var end: Date?              // เวลาที่ฝนน่าจะหยุด (ตอนกำลังตก)
    var peakDBZ: Int?           // ความแรงสูงสุดที่คาดว่าจะผ่านสวน
    var nearestKm: Double?
    var nearestBearing: Double? // องศา (จากสวนไปหาฝน)
    var motionKmh: Double?
    var motionFromDeg: Double?  // ทิศที่ฝนเคลื่อน "มาจาก" (แบบทิศลม)
    var outlook: [OutlookPoint] = []    // ทุก 5 นาที นับจากเวลาภาพล่าสุด (ว่าง = ไม่รู้ทิศ)
    var rangeKm: Double = 140           // รัศมีที่วิเคราะห์
    var motionVector: CGVector?         // พิกเซล/นาที (x ไปทางตะวันออก, y ไปทางใต้)

    /// ระดับความแรงจาก dBZ (เกณฑ์ทั่วไปของเรดาร์ตรวจอากาศ)
    static func intensity(_ dbz: Int) -> String {
        switch dbz {
        case ..<30: return "เบา"
        case ..<40: return "ปานกลาง"
        case ..<50: return "หนัก"
        default:    return "หนักมาก/พายุ"
        }
    }

    /// ข้อความสั้นสำหรับการ์ด — นับนาทีจาก now ทุกครั้งที่วาด ให้ตัวเลขเดินลงเองระหว่างรอบดึงภาพ
    /// sensorRate: ฝนที่เซนเซอร์สวนวัดได้ตอนนี้ (มม./ชม.) — เรดาร์เห็นฝนแต่เซนเซอร์ยังแห้ง = ฝนยังไม่ถึงพื้น/อยู่ข้าง ๆ
    func headline(now: Date = Date(), sensorRate: Double? = nil) -> String {
        func mins(_ d: Date) -> Int { max(0, Int((d.timeIntervalSince(now) / 60).rounded())) }
        switch status {
        case .raining:
            let i = peakDBZ.map { " (\(Self.intensity($0)))" } ?? ""
            if sensorRate == 0 {
                return "เรดาร์เห็นฝน\(peakDBZ.map { Self.intensity($0) } ?? "")เหนือสวน แต่เซนเซอร์ยังไม่วัดได้"
            }
            if let end, mins(end) > 0 { return "ฝนกำลังตก\(i) น่าจะหยุดใน ~\(mins(end)) นาที" }
            return "ฝนกำลังตกที่สวน\(i)"
        case .approaching:
            let i = peakDBZ.map { " (\(Self.intensity($0)))" } ?? ""
            let e = eta.map(mins) ?? 0
            return e <= 5 ? "ฝนกำลังจะถึงสวน\(i)" : "ฝนจะถึงสวนในอีก ~\(e) นาที\(i)"
        case .nearby:
            guard let km = nearestKm else { return "มีฝนในพื้นที่" }
            let dir = nearestBearing.map { " ทาง\(Self.thaiCompass($0))" } ?? ""
            return String(format: "มีฝนห่าง ~%.0f กม.%@", km, dir)
        case .clear:
            return String(format: "ไม่มีกลุ่มฝนในรัศมี ~%.0f กม.", rangeKm)
        }
    }

    /// รายละเอียดบรรทัดที่สอง เช่น "มาจากทิศตะวันออก ~18 กม./ชม."
    var detail: String? {
        var parts: [String] = []
        if status == .approaching, let km = nearestKm {
            parts.append(String(format: "ห่าง %.0f กม.", km))
        }
        if status == .nearby { parts.append("ยังไม่มุ่งมาที่สวน") }
        if let from = motionFromDeg, let v = motionKmh, status != .clear {
            parts.append(v < 3 ? "แทบไม่เคลื่อนที่"
                               : String(format: "มาจากทิศ%@ ~%.0f กม./ชม.", Self.thaiCompass(from), v))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    static func thaiCompass(_ deg: Double) -> String {
        let names = ["เหนือ", "ตะวันออกเฉียงเหนือ", "ตะวันออก", "ตะวันออกเฉียงใต้",
                     "ใต้", "ตะวันตกเฉียงใต้", "ตะวันตก", "ตะวันตกเฉียงเหนือ"]
        let i = Int(((deg.truncatingRemainder(dividingBy: 360) + 360 + 22.5) / 45).rounded(.down)) % 8
        return names[i]
    }
}

struct RadarSnapshot {
    let frames: [RadarFrame]    // เก่า → ใหม่
    let forecast: [RadarFrame]  // ภาพคาดการณ์ +10…+60 นาที (ภาพล่าสุดเลื่อนตามทิศที่ฝนเคลื่อน)
    let basemap: CGImage?
    let nowcast: RadarNowcast?
    let size: Int
    let kmPerPixel: Double
    /// ตำแหน่งสวนในภาพ (พิกเซล, มุมซ้ายบนเป็น 0,0)
    let garden: CGPoint
}

final class RainRadarService {
    static let zoom = 7                 // ระดับซูมสูงสุดที่ RainViewer ให้ (~1.2 กม./พิกเซลแถวจันทบุรี)
    static let radius = 200             // พิกเซลรอบสวน → ภาพ 400×400 (±240 กม.)
    static let analysisRadius = 120     // วิเคราะห์ทิศ/ETA เฉพาะ ±140 กม. (ไกลกว่านั้นไม่ทันใน 2 ชม. และช้า)
    static let rainDBZ = 20             // เกณฑ์ "ฝนถึงพื้น" (~0.5–1 มม./ชม.)

    private let lat: Double
    private let lon: Double
    private let session: URLSession
    private var cache: [String: RadarFrame] = [:]   // path → เฟรม (ภาพย้อนหลังไม่เปลี่ยน)
    private var basemap: CGImage?

    init(latitude: Double, longitude: Double) {
        lat = latitude
        lon = longitude
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        session = URLSession(configuration: cfg)
    }

    private var size: Int { Self.radius * 2 }

    /// พิกัดพิกเซลโลก (Web Mercator) ของสวนที่ซูม z
    private var worldPixel: (x: Double, y: Double) {
        let n = Double(1 << Self.zoom) * 256
        let x = (lon + 180) / 360 * n
        let y = (1 - asinh(tan(lat * .pi / 180)) / .pi) / 2 * n
        return (x, y)
    }
    private var origin: (x: Int, y: Int) {
        let p = worldPixel
        return (Int(p.x) - Self.radius, Int(p.y) - Self.radius)
    }
    var kmPerPixel: Double {
        40075.016686 * cos(lat * .pi / 180) / (Double(1 << Self.zoom) * 256)
    }

    func fetch() async throws -> RadarSnapshot {
        let mapsURL = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!
        let (data, _) = try await get(mapsURL)
        let maps = try JSONDecoder().decode(Maps.self, from: data)
        let past = maps.radar.past.suffix(13)

        // ดึงเฉพาะเฟรมที่ยังไม่มี พร้อมกันทุกเฟรม (ครั้งแรก 13 เฟรม × 4 ไทล์ — ทีละอันช้าเกิน)
        let missing = past.filter { cache[$0.path] == nil }
        let fetched = try await withThrowingTaskGroup(of: (String, RadarFrame).self) { group in
            for f in missing {
                group.addTask {
                    let img = try await self.stitch { tx, ty in
                        URL(string: "\(maps.host)\(f.path)/256/\(Self.zoom)/\(tx)/\(ty)/2/0_0.png")!
                    }
                    return (f.path, RadarFrame(time: Date(timeIntervalSince1970: f.time), image: img,
                                               dbz: Self.decode(img)))
                }
            }
            return try await group.reduce(into: [String: RadarFrame]()) { $0[$1.0] = $1.1 }
        }
        cache.merge(fetched) { _, new in new }
        let frames = past.compactMap { cache[$0.path] }
        let keep = Set(past.map(\.path))
        cache = cache.filter { keep.contains($0.key) }

        if basemap == nil { basemap = try? await loadBasemap() }

        let p = worldPixel, o = origin
        let garden = CGPoint(x: p.x - Double(o.x), y: p.y - Double(o.y))
        // วิเคราะห์เฉพาะกลางภาพ ±analysisRadius
        let a = Self.analysisRadius, cut = Self.radius - a
        let inner = frames.map { f in
            RadarFrame(time: f.time, image: f.image, dbz: Self.crop(f.dbz, size: size, from: cut, to: 2 * a))
        }
        var cast = Self.analyze(inner, garden: CGPoint(x: garden.x - Double(cut), y: garden.y - Double(cut)),
                                kmPerPixel: kmPerPixel)
        cast?.rangeKm = Double(a) * kmPerPixel
        let forecast = frames.last.map { Self.extrapolate($0, motion: cast?.motionVector) } ?? []
        return RadarSnapshot(frames: frames, forecast: forecast, basemap: basemap, nowcast: cast,
                             size: size, kmPerPixel: kmPerPixel, garden: garden)
    }

    private static func crop(_ d: [UInt8], size: Int, from: Int, to n: Int) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: n * n)
        for y in 0..<n {
            let src = (y + from) * size + from
            out.replaceSubrange((y * n)..<(y * n + n), with: d[src..<(src + n)])
        }
        return out
    }

    /// ภาพคาดการณ์ +10…+60 นาที: เลื่อนภาพล่าสุดไปตามทิศที่ฝนเคลื่อน (ฝนแรงเท่าเดิม ไม่เกิด/ไม่สลาย)
    private static func extrapolate(_ last: RadarFrame, motion v: CGVector?) -> [RadarFrame] {
        guard let v, (v.dx * v.dx + v.dy * v.dy).squareRoot() * 60 >= 2 else { return [] }   // < ~2.4 กม./ชม. = อยู่กับที่
        let w = last.image.width, h = last.image.height
        return stride(from: 10, through: 60, by: 10).compactMap { t -> RadarFrame? in
            guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            // y ของภาพชี้ลง แต่ CGContext นับขึ้น
            ctx.draw(last.image, in: CGRect(x: v.dx * Double(t), y: -v.dy * Double(t), width: Double(w), height: Double(h)))
            guard let img = ctx.makeImage() else { return nil }
            return RadarFrame(time: last.time.addingTimeInterval(Double(t) * 60), image: img, dbz: [], isForecast: true)
        }
    }

    // MARK: - ดาวน์โหลด/ต่อภาพ

    private func get(_ url: URL) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: url)
        req.setValue("Argard-macOS (personal weather station)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode) \(url.host ?? "")"])
        }
        return (data, resp)
    }

    /// ดึงไทล์ที่คร่อมกรอบภาพรอบสวน แล้วตัดมาเป็นภาพ size × size
    /// scale = ความละเอียดของไทล์เทียบกับซูมเรดาร์ (แผนที่ฐานใช้ 2 เพื่อให้คมบนจอ retina)
    private func stitch(scale: Int = 1, url: (Int, Int) -> URL) async throws -> CGImage {
        let o = origin, s = size
        let px = s * scale, tilePx = 256
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw URLError(.cannotDecodeContentData) }
        let ox = o.x * scale, oy = o.y * scale
        var jobs: [(tx: Int, ty: Int, url: URL)] = []
        for ty in (oy / tilePx)...((oy + px - 1) / tilePx) {
            for tx in (ox / tilePx)...((ox + px - 1) / tilePx) { jobs.append((tx, ty, url(tx, ty))) }
        }
        let tiles = try await withThrowingTaskGroup(of: (Int, Int, Data).self) { group in
            for j in jobs {
                group.addTask { (j.tx, j.ty, try await self.get(j.url).0) }
            }
            return try await group.reduce(into: [(Int, Int, Data)]()) { $0.append($1) }
        }
        for (tx, ty, data) in tiles {
            guard let src = CGImageSourceCreateWithData(data as CFData, nil),
                  let tile = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
            // CGContext นับ y จากล่างขึ้นบน
            let x = tx * tilePx - ox
            let yTop = ty * tilePx - oy
            ctx.draw(tile, in: CGRect(x: x, y: px - yTop - tilePx, width: tilePx, height: tilePx))
        }
        guard let img = ctx.makeImage() else { throw URLError(.cannotDecodeContentData) }
        return img
    }

    /// แผนที่ฐานโทนมืด (Esri World Dark Gray) — ดึงครั้งเดียวแล้วเก็บไว้ในเครื่อง
    private func loadBasemap() async throws -> CGImage {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Argard", isDirectory: true)
        let file = dir.appendingPathComponent(String(format: "basemap-%.4f-%.4f-z%d-r%d.png", lat, lon, Self.zoom, Self.radius))
        if let src = CGImageSourceCreateWithURL(file as CFURL, nil),
           let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            return img
        }
        let z = Self.zoom + 1
        let base = "https://server.arcgisonline.com/ArcGIS/rest/services/Canvas"
        let img = try await stitch(scale: 2) { tx, ty in
            URL(string: "\(base)/World_Dark_Gray_Base/MapServer/tile/\(z)/\(ty)/\(tx)")!
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let dest = CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(dest, img, nil)
            CGImageDestinationFinalize(dest)
        }
        return img
    }

    // MARK: - สี → dBZ

    /// ตารางสี Universal Blue (scheme 2) ของ RainViewer ช่วงฝน 15…65 dBZ (สีทึบ)
    /// ต่ำกว่า 15 dBZ เป็นสีโปร่งแสง = ละอองฝน/ไม่ถึงพื้น ไม่ต้องใช้
    static let palette: [UInt32] = [
        0x88DDEE, 0x6CD1EB, 0x51C5E8, 0x36BAE5, 0x1BAEE2, 0x00A3E0, 0x009AD5, 0x0091CA, 0x0088BF, 0x007FB4,
        0x0077AA, 0x0070A3, 0x00699C, 0x006295, 0x005B8E, 0x005588, 0x005180, 0x004E78, 0x004A70, 0x004768,
        0xFFEE00, 0xFFE000, 0xFFD200, 0xFFC500, 0xFFB700, 0xFFAA00, 0xFF9F00, 0xFF9500, 0xFF8B00, 0xFF8100,
        0xFF4400, 0xF23600, 0xE62800, 0xD91B00, 0xCD0D00, 0xC10000, 0xA80000, 0x8F0000, 0x760000, 0x5D0000,
        0xFFAAFF, 0xFF9FFF, 0xFF95FF, 0xFF8BFF, 0xFF81FF, 0xFF77FF, 0xFF6CFF, 0xFF62FF, 0xFF58FF, 0xFF4EFF,
        0xFFFFFF,
    ]
    static let paletteMinDBZ = 15
    /// สี RGB (0xRRGGBB) ของค่า dBZ ตามสเกลเดียวกับภาพเรดาร์
    static func color(dbz: Int) -> UInt32 {
        palette[min(max(dbz - paletteMinDBZ, 0), palette.count - 1)]
    }
    private static let lookup: [UInt32: UInt8] = {
        var d: [UInt32: UInt8] = [:]
        for (i, c) in palette.enumerated() where d[c] == nil { d[c] = UInt8(paletteMinDBZ + i) }
        return d
    }()

    private static func decode(_ img: CGImage) -> [UInt8] {
        let w = img.width, h = img.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return [] }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        var out = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) where buf[i * 4 + 3] == 255 {
            let c = UInt32(buf[i * 4]) << 16 | UInt32(buf[i * 4 + 1]) << 8 | UInt32(buf[i * 4 + 2])
            out[i] = lookup[c] ?? nearest(c)
        }
        return out      // แถวบนสุดของภาพอยู่ที่ index 0 (CGContext เขียนบัฟเฟอร์จากบนลงล่าง)
    }

    /// สีที่ไม่ตรงตาราง (ขอบภาพที่ถูกย่อ/ผสม) → ค่าที่ใกล้ที่สุด
    private static func nearest(_ c: UInt32) -> UInt8 {
        func rgb(_ v: UInt32) -> (Int, Int, Int) { (Int(v >> 16 & 255), Int(v >> 8 & 255), Int(v & 255)) }
        let a = rgb(c)
        var best = 0, bestD = Int.max
        for (i, p) in palette.enumerated() {
            let b = rgb(p)
            let d = (a.0 - b.0) * (a.0 - b.0) + (a.1 - b.1) * (a.1 - b.1) + (a.2 - b.2) * (a.2 - b.2)
            if d < bestD { bestD = d; best = i }
        }
        return bestD < 3000 ? UInt8(paletteMinDBZ + best) : 0
    }

    // MARK: - วิเคราะห์

    /// ทิศ/ความเร็วการเคลื่อนของกลุ่มฝน (พิกเซลต่อนาที) จากการเทียบเฟรมต่อกันแบบ block matching
    static func motion(_ frames: [RadarFrame], size: Int) -> (dx: Double, dy: Double)? {
        let recent = Array(frames.suffix(7))        // ~1 ชม.ล่าสุด
        guard recent.count >= 3 else { return nil }
        let maxShift = 8                            // 8 px/10 นาที ≈ 57 กม./ชม.
        var vx: [Double] = [], vy: [Double] = []
        for k in 1..<recent.count {
            let a = recent[k - 1], b = recent[k]
            let dt = b.time.timeIntervalSince(a.time) / 60
            guard dt >= 5, dt <= 20 else { continue }
            let rainA = a.dbz.map { Int($0) >= rainDBZ }, rainB = b.dbz.map { Int($0) >= rainDBZ }
            let nA = rainA.filter { $0 }.count, nB = rainB.filter { $0 }.count
            guard nA >= 40, nB >= 40 else { continue }
            var best = (score: -1.0, dx: 0, dy: 0)
            for dy in -maxShift...maxShift {
                for dx in -maxShift...maxShift {
                    var hit = 0
                    for y in max(0, -dy)..<min(size, size - dy) {
                        let rowA = y * size, rowB = (y + dy) * size
                        for x in max(0, -dx)..<min(size, size - dx) where rainA[rowA + x] && rainB[rowB + x + dx] {
                            hit += 1
                        }
                    }
                    // เอียงเข้าหา "ไม่เคลื่อน" นิดหน่อยเมื่อคะแนนสูสี (กันสัญญาณรบกวนลากไปไกล)
                    let score = Double(hit) - 0.02 * Double(dx * dx + dy * dy)
                    if score > best.score { best = (score, dx, dy) }
                }
            }
            guard Double(best.score) > 0.3 * Double(min(nA, nB)) else { continue }   // จับคู่ไม่ติด
            vx.append(Double(best.dx) / dt)
            vy.append(Double(best.dy) / dt)
        }
        guard vx.count >= 2 else { return nil }
        func median(_ v: [Double]) -> Double { let s = v.sorted(); return s[s.count / 2] }
        return (median(vx), median(vy))
    }

    static func analyze(_ frames: [RadarFrame], garden: CGPoint, kmPerPixel: Double) -> RadarNowcast? {
        guard let last = frames.last else { return nil }
        let size = Int(Double(last.dbz.count).squareRoot())
        guard size > 0 else { return nil }
        let gx = Double(garden.x), gy = Double(garden.y)

        /// dBZ สูงสุดรอบจุด ±r พิกเซล — ตอนนี้ใช้ ±1 (~1.2 กม.) อนาคตใช้ ±2 (~2.4 กม.) ชดเชยทิศที่คลาดได้
        func maxDBZ(_ f: RadarFrame, x: Double, y: Double, r: Int) -> Int? {
            let cx = Int(x.rounded()), cy = Int(y.rounded())
            guard cx >= r, cy >= r, cx < size - r, cy < size - r else { return nil }   // หลุดขอบภาพ = ไม่รู้
            var m = 0
            for yy in (cy - r)...(cy + r) { for xx in (cx - r)...(cx + r) { m = max(m, Int(f.dbz[yy * size + xx])) } }
            return m
        }

        // ฝนที่ใกล้ที่สุดในภาพล่าสุด
        var nearest: (d2: Double, x: Double, y: Double)?
        for y in 0..<size {
            for x in 0..<size where Int(last.dbz[y * size + x]) >= rainDBZ {
                let d2 = (Double(x) - gx) * (Double(x) - gx) + (Double(y) - gy) * (Double(y) - gy)
                if nearest == nil || d2 < nearest!.d2 { nearest = (d2, Double(x), Double(y)) }
            }
        }
        var cast = RadarNowcast(status: .clear, frameTime: last.time)
        guard let n = nearest else { return cast }
        cast.nearestKm = n.d2.squareRoot() * kmPerPixel
        // ทิศจากสวนไปหาฝน (y ของภาพชี้ลงใต้)
        cast.nearestBearing = (atan2(n.x - gx, gy - n.y) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)

        var v = motion(frames, size: size)
        if let m = v {
            let pxPerMin = (m.dx * m.dx + m.dy * m.dy).squareRoot()
            cast.motionKmh = pxPerMin * kmPerPixel * 60
            // "มาจาก" = ทิศตรงข้ามกับทิศที่เคลื่อนไป
            cast.motionFromDeg = (atan2(-m.dx, m.dy) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
            // ช้ากว่า 3 กม./ชม. = ฝนก่อตัวอยู่กับที่ — เลื่อนภาพไปข้างหน้าไม่มีความหมาย ดูแค่ตอนนี้
            if cast.motionKmh! < 3 { v = nil } else { cast.motionVector = CGVector(dx: m.dx, dy: m.dy) }
        }

        // จำลองไปข้างหน้าทีละ 5 นาที (นับจากเวลาภาพ) — ค่าที่สวน ณ เวลา t = ค่าในภาพล่าสุดที่จุด (สวน − v·t)
        let horizon = 120
        var series: [(min: Int, dbz: Int)] = []
        for t in stride(from: 0, through: horizon, by: 5) {
            let x = gx - (v?.dx ?? 0) * Double(t), y = gy - (v?.dy ?? 0) * Double(t)
            guard let d = maxDBZ(last, x: x, y: y, r: t == 0 ? 1 : 2) else { break }
            series.append((t, d))
            if v == nil { break }       // ไม่รู้ทิศ — ดูได้แค่ตอนนี้
        }
        let at = { (t: Int) in last.time.addingTimeInterval(Double(t) * 60) }
        if v != nil { cast.outlook = series.map { OutlookPoint(time: at($0.min), dbz: $0.dbz) } }
        let wet = series.filter { $0.dbz >= rainDBZ }

        if let first = series.first, first.dbz >= rainDBZ {
            cast.status = .raining
            cast.peakDBZ = series.prefix { $0.dbz >= rainDBZ }.map(\.dbz).max()
            if v != nil, let end = series.first(where: { $0.dbz < rainDBZ }) { cast.end = at(end.min) }
        } else if let start = wet.first {
            // ภาพช้ากว่าจริง 10–20 นาที — ถ้าเวลาที่ทำนายผ่านไปแล้ว headline จะขึ้น "กำลังจะถึง"
            cast.status = .approaching
            cast.eta = at(start.min)
            cast.peakDBZ = series.drop { $0.dbz < rainDBZ }.prefix { $0.dbz >= rainDBZ }.map(\.dbz).max()
        } else {
            cast.status = .nearby
        }
        return cast
    }

    // MARK: - JSON

    private struct Maps: Decodable {
        struct Frame: Decodable { let time: TimeInterval; let path: String }
        struct Radar: Decodable { let past: [Frame] }
        let host: String
        let radar: Radar
    }
}
