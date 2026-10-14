import Foundation
import os

/// ให้ Gemini วิเคราะห์ว่าอากาศตอนนี้เหมาะกับการพ่นยาหรือไม่
/// ขั้นตอน: กดปุ่ม → ดึงค่าล่าสุดจาก Weather Station (store) → ส่ง prompt + ค่าอากาศ
/// ให้ Gemini → เก็บคำตอบไว้แสดงบนหน้า Agriculture
/// (สร้างไว้ที่ ContentView — สลับแท็บไปมาแล้วค่าที่กรอกและผลวิเคราะห์ยังอยู่)
@MainActor
final class SprayAdvisor: ObservableObject {

    enum SprayType: String, CaseIterable, Identifiable {
        case insecticide, fungicide, foliar, herbicide
        var id: String { rawValue }
        var label: String {
            switch self {
            case .insecticide: "ยาฆ่าแมลง"
            case .fungicide: "ยาเชื้อรา"
            case .foliar: "ปุ๋ยทางใบ"
            case .herbicide: "ยาฆ่าหญ้า"
            }
        }
        /// ชื่อเต็มที่ใช้ใน prompt
        var promptName: String {
            switch self {
            case .insecticide: "ยาฆ่าแมลง"
            case .fungicide: "ยาป้องกันกำจัดเชื้อรา"
            case .foliar: "ปุ๋ยทางใบ/ฮอร์โมน"
            case .herbicide: "ยาฆ่าหญ้า"
            }
        }
    }

    enum Timing: String, CaseIterable, Identifiable {
        case now, within3h, within6h
        var id: String { rawValue }
        var label: String {
            switch self {
            case .now: "ตอนนี้"
            case .within3h: "ภายใน 3 ชม."
            case .within6h: "ภายใน 6 ชม."
            }
        }
        var promptText: String {
            switch self {
            case .now: "ตั้งใจจะพ่นทันที"
            case .within3h: "ตั้งใจจะพ่นภายใน 3 ชั่วโมงข้างหน้า"
            case .within6h: "ตั้งใจจะพ่นภายใน 6 ชั่วโมงข้างหน้า"
            }
        }
    }

    static let cropPresets = ["ทุเรียน", "มังคุด", "เงาะ", "ลองกอง", "ลำไย"]
    static let otherCrop = "อื่นๆ"

    // MARK: ค่าที่ผู้ใช้กรอก (พืช/สารที่พ่น จำไว้ข้ามการเปิดแอพ)
    @Published var crop: String {
        didSet { UserDefaults.standard.set(crop, forKey: "agri.crop") }
    }
    @Published var customCrop: String {
        didSet { UserDefaults.standard.set(customCrop, forKey: "agri.customCrop") }
    }
    /// สารที่จะพ่น — เลือกได้หลายอย่าง (เช็คบ็อกซ์)
    @Published var sprayTypes: Set<SprayType> {
        didSet { UserDefaults.standard.set(sprayTypes.map(\.rawValue), forKey: "agri.sprayTypes") }
    }
    @Published var timing: Timing = .now
    @Published var note = ""

    // MARK: Gemini
    @Published private(set) var apiKey: String
    let model: String

    // MARK: ผลลัพธ์
    @Published private(set) var isLoading = false
    @Published private(set) var answer = ""
    @Published private(set) var errorText = ""
    @Published private(set) var retryNote = ""      // ข้อความระหว่างลองส่งใหม่ (Gemini ไม่ว่าง)
    @Published private(set) var lastPrompt = ""
    @Published private(set) var dataTime: Date?     // เวลาที่สถานีวัดค่าที่ส่งไป
    @Published private(set) var askedAt: Date?

    private let logger = Logger(subsystem: "th.suphanutthanyaboon.argard", category: "gemini")

    init(config: AppConfig = AppConfig.load()) {
        let d = UserDefaults.standard
        crop = d.string(forKey: "agri.crop") ?? Self.cropPresets[0]
        customCrop = d.string(forKey: "agri.customCrop") ?? ""
        // เดิมเก็บเป็นตัวเลือกเดียว (agri.sprayType) — อ่านต่อให้ ถ้ายังไม่มีค่าแบบหลายตัว
        if let saved = d.stringArray(forKey: "agri.sprayTypes") {
            sprayTypes = Set(saved.compactMap(SprayType.init(rawValue:)))
        } else {
            sprayTypes = [d.string(forKey: "agri.sprayType").flatMap(SprayType.init(rawValue:)) ?? .insecticide]
        }
        apiKey = config.geminiAPIKey
        model = config.geminiModel
    }

    /// สารที่เลือก เรียงตามลำดับบนหน้าจอ
    var selectedSprays: [SprayType] { SprayType.allCases.filter(sprayTypes.contains) }

    /// ข้อความต่อท้าย "วิเคราะห์อากาศเพื่อการพ่น…" บนปุ่ม
    var sprayButtonText: String {
        let s = selectedSprays
        return s.count == 1 ? s[0].label : "ยา (\(s.count) อย่าง)"
    }

    private var sprayPromptNames: String { selectedSprays.map(\.promptName).joined(separator: " และ ") }

    var hasAPIKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    /// ชื่อพืชที่ใช้จริง — เลือก "อื่นๆ" แล้วไม่ได้พิมพ์ชื่อ ถือเป็นพืชสวนทั่วไป
    var cropName: String {
        guard crop == Self.otherCrop else { return crop }
        let t = customCrop.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "พืชสวน" : t
    }

    func saveAPIKey(_ key: String) throws {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try AppConfig.saveGeminiKey(k)
        apiKey = k
        errorText = ""
    }

    // MARK: - วิเคราะห์

    func analyze(store: WeatherStore) async {
        guard !isLoading else { return }
        guard hasAPIKey else {
            errorText = "ยังไม่ได้ใส่ Gemini API key"
            return
        }
        guard !sprayTypes.isEmpty else {
            errorText = "เลือกสารที่จะพ่นอย่างน้อย 1 อย่าง"
            return
        }
        // 1. ดึงค่าล่าสุดจาก Weather Station ณ ตอนกดปุ่ม
        let prompt = buildPrompt(obs: store.obs, forecast: store.forecast)
        lastPrompt = prompt
        dataTime = store.obs.obsTimeUtc
        answer = ""
        errorText = ""
        isLoading = true
        defer { isLoading = false }

        // 2. ส่ง prompt + ค่าอากาศไปให้ Gemini
        logger.log("ส่งให้ Gemini model=\(self.model, privacy: .public) crop=\(self.cropName, privacy: .public) spray=\(self.selectedSprays.map(\.rawValue).joined(separator: ","), privacy: .public)")
        // Gemini ไม่ว่างชั่วคราว (503 ฯลฯ) → ลองใหม่เองสูงสุด 3 ครั้ง เว้น 2, 4, 8 วิ
        let gemini = GeminiService(apiKey: apiKey, model: model)
        let retryDelays: [UInt64] = [2, 4, 8]
        defer { retryNote = "" }
        for attempt in 0...retryDelays.count {
            do {
                let text = try await gemini.generate(system: systemInstruction, prompt: prompt, temperature: 0.3)
                // 3. เก็บคำตอบไว้แสดงบนหน้าจอ
                answer = text
                askedAt = Date()
                logger.log("Gemini ตอบกลับ \(text.count, privacy: .public) ตัวอักษร (ครั้งที่ \(attempt + 1, privacy: .public))")
                return
            } catch let error as GeminiService.GeminiError where error.isRetryable && attempt < retryDelays.count {
                retryNote = "Gemini มีคนใช้เยอะ กำลังลองใหม่ (ครั้งที่ \(attempt + 2)/\(retryDelays.count + 1))..."
                logger.log("Gemini ไม่ว่าง ลองใหม่ใน \(retryDelays[attempt], privacy: .public) วิ: \(error.errorDescription ?? "", privacy: .public)")
                try? await Task.sleep(nanoseconds: retryDelays[attempt] * 1_000_000_000)
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                logger.error("Gemini ผิดพลาด: \(self.errorText, privacy: .public)")
                return
            }
        }
    }

    /// บทบาทของ AI — ผู้เชี่ยวชาญสวน ตอบสั้น เข้าใจง่าย สไตล์ชาวสวน
    private var systemInstruction: String {
        """
        คุณเป็นผู้เชี่ยวชาญด้านการทำสวน\(cropName)
        หน้าที่ของคุณคือ วิเคราะห์ค่าสภาพอากาศจาก Weather Station แล้วประเมินว่า \
        'เหมาะกับการพ่น\(sprayPromptNames)ให้\(cropName)หรือไม่'
        พร้อมให้เหตุผลสั้นๆ เข้าใจง่าย สไตล์ชาวสวน
        ถ้าจะพ่นหลายอย่าง ให้ระบุว่าสภาพอากาศตอนนี้เหมาะกับสารแต่ละอย่างหรือไม่ \
        (บางอย่างอาจเหมาะ บางอย่างอาจไม่เหมาะ)

        รูปแบบคำตอบ:
        - บรรทัดแรกขึ้นต้นด้วย ✅ (เหมาะ) หรือ ⚠️ (พ่นได้แต่ต้องระวัง) หรือ ❌ (ไม่ควรพ่น) \
        ตามด้วยสรุปหนึ่งประโยค
        - เหตุผลเป็นข้อๆ ไม่เกิน 5 ข้อ อ้างอิงตัวเลขจากสถานี
        - ถ้ายังไม่เหมาะ ให้แนะนำช่วงเวลาที่ดีกว่าจากพยากรณ์รายชั่วโมงที่ให้มา
        """
    }

    private static let thaiTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "th_TH")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "HH:mm"
        return f
    }()

    static func thaiTimeText(_ date: Date) -> String { thaiTime.string(from: date) + " น." }

    /// รวมค่าจาก Weather Station + แผนการพ่น + พยากรณ์ 6 ชม. เป็นข้อความส่งให้ Gemini
    private func buildPrompt(obs: PWSObservation, forecast: [OWForecastItem]) -> String {
        let m = obs.metric
        let dir = obs.winddir.map { "\(WX.degToCompass($0)) (\(Int($0))°)" } ?? "-"
        var lines = [
            "ช่วยประเมินสภาพอากาศจาก Weather Station สวน\(cropName)ตอนนี้ให้หน่อยครับ:",
            "- อุณหภูมิ (Temperature): \(WX.fmt(m.temp)) °C",
            "- อุณหภูมิที่รู้สึก (Heat Index): \(WX.fmt(m.heatIndex)) °C",
            "- ความชื้น (Humidity): \(WX.fmtInt(obs.humidity)) %",
            "- จุดน้ำค้าง (Dew Point): \(WX.fmt(m.dewpt)) °C",
            "- ฝนตกขณะนี้ (Rain Rate): \(WX.fmt(m.precipRate, 2)) mm/h",
            "- ปริมาณฝนสะสมวันนี้ (Rainfall): \(WX.fmt(m.precipTotal)) mm",
            "- ความเร็วลม (Wind Speed): \(WX.fmt(m.windSpeed)) km/h",
            "- ลมกระโชก (Wind Gust): \(WX.fmt(m.windGust)) km/h",
            "- ทิศทางลม (Wind Direction, ทิศที่ลมพัดมา): \(dir)",
            "- ความกดอากาศ (Pressure): \(WX.fmt(m.pressure)) hPa",
            "- การแผ่รังสีดวงอาทิตย์ (Solar Radiation): \(WX.fmtInt(obs.solarRadiation)) W/m²",
            "- ค่า UV Index: \(WX.fmtInt(obs.uv))",
            "- เวลาที่วัด: \(Self.thaiTimeText(obs.obsTimeUtc ?? Date()))",
            "",
            "แผนการพ่น:",
            "- สารที่จะพ่น: \(sprayPromptNames)",
            "- ช่วงเวลา: \(timing.promptText)",
        ]
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { lines.append("- หมายเหตุจากชาวสวน: \(n)") }

        // พยากรณ์ชั่วโมงปัจจุบัน + 5 ชม.ถัดไป — ใช้ดูว่าฝนจะชะยาหรือไม่ และหาช่วงที่ดีกว่า
        let now = Date().timeIntervalSince1970
        let upcoming = forecast.filter { $0.dt + 3600 > now }.prefix(6)
        if !upcoming.isEmpty {
            lines += ["", "พยากรณ์รายชั่วโมงข้างหน้า:"]
            for h in upcoming {
                let t = Self.thaiTimeText(Date(timeIntervalSince1970: h.dt))
                lines.append("- \(t) \(WX.fmt(h.temp)) °C, ความชื้น \(WX.fmtInt(h.humidity)) %, "
                    + "โอกาสฝน \(WX.fmtInt((h.pop ?? 0) * 100)) %, ฝน \(WX.fmt(h.rain)) mm, "
                    + "ลม \(WX.fmt(WX.msToKmh(h.windSpeed), 0)) km/h, \(h.weatherDesc)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
