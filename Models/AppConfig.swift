import Foundation

/// ค่า config เริ่มต้น (ตรงกับ config.ini ของโปรแกรม Python เดิม)
/// ตอนรันครั้งแรก แอพจะสร้างไฟล์ config.ini ที่
/// ~/Library/Application Support/Argard/config.ini ให้แก้ไขได้เอง
struct AppConfig {
    var stationID: String = "IMAKHA6"
    var weatherComAPIKey: String = "12f3d3276a7b4190b3d3276a7bd1908d"
    var openWeatherAPIKey: String = "fe95920166f28786c34849635cc40d2e"
    var latitude: Double = 12.701
    var longitude: Double = 102.231
    var refreshSeconds: Int = 60
    /// โมเดลพยากรณ์ของ Open-Meteo — icon_seamless แม่นสุดที่พิกัดสวน
    /// (ทดสอบย้อนหลัง 15 ก.ค.–13 ต.ค. 2026 เทียบ 9 โมเดล) / เว้นว่างหรือ best_match = ให้ Open-Meteo เลือกเอง
    var forecastModel: String = "icon_seamless"
    /// ปรับอุณหภูมิ/ความชื้น/ลมของพยากรณ์ด้วยค่าจริงจากเซนเซอร์
    var sensorCorrection: Bool = true
    var geminiAPIKey: String = ""
    var geminiModel: String = "gemini-3.8-flash"

    static let supportDir = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Argard", isDirectory: true)
    static let configURL = supportDir.appendingPathComponent("config.ini")

    static func load() -> AppConfig {
        let fm = FileManager.default
        if !fm.fileExists(atPath: supportDir.path) {
            try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
        }
        // ยังไม่มีไฟล์ → สร้างไฟล์ default ให้
        if !fm.fileExists(atPath: configURL.path) {
            try? defaultFileText.write(to: configURL, atomically: true, encoding: .utf8)
            return AppConfig()
        }
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else {
            return AppConfig()
        }
        return parse(text)
    }

    static var defaultFileText: String {
        """
        # Argard — Personal Weather Station config
        # แก้ค่าแล้วเปิดแอพใหม่ (หรือกด Refresh) ได้เลย
        [WeatherCom]
        STATION_ID = IMAKHA6
        API_KEY = 12f3d3276a7b4190b3d3276a7bd1908d

        [OpenWeather]
        API_KEY = fe95920166f28786c34849635cc40d2e
        LATITUDE = 12.701
        LONGITUDE = 102.231

        [General]
        REFRESH_SECONDS = 60

        [Forecast]
        # โมเดลพยากรณ์ Open-Meteo เช่น ukmo_seamless, icon_seamless, gfs_seamless, best_match
        MODEL = icon_seamless
        # ปรับอุณหภูมิ/ความชื้น/ลมของพยากรณ์ด้วยค่าจริงจากเซนเซอร์ (on/off)
        SENSOR_CORRECTION = on

        [Gemini]
        # ขอ key ฟรีที่ https://aistudio.google.com/apikey (หรือใส่ผ่านแท็บ Agriculture)
        API_KEY =
        MODEL = gemini-3.8-flash
        """
    }

    /// ตัว parse ไฟล์ .ini แบบง่าย (section + key = value)
    static func parse(_ text: String) -> AppConfig {
        var cfg = AppConfig()
        var section = ""
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") { continue }
            if line.hasPrefix("["), let end = line.firstIndex(of: "]") {
                section = String(line[line.index(after: line.startIndex)..<end]).lowercased()
                continue
            }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).uppercased()
            let value = String(line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces))
            switch (section, key) {
            case ("weathercom", "STATION_ID"): cfg.stationID = value
            case ("weathercom", "API_KEY"): cfg.weatherComAPIKey = value
            case ("openweather", "API_KEY"): cfg.openWeatherAPIKey = value
            case ("openweather", "LATITUDE"): cfg.latitude = Double(value) ?? cfg.latitude
            case ("openweather", "LONGITUDE"): cfg.longitude = Double(value) ?? cfg.longitude
            case ("general", "REFRESH_SECONDS"): cfg.refreshSeconds = Int(value) ?? cfg.refreshSeconds
            case ("forecast", "MODEL"): cfg.forecastModel = value
            case ("forecast", "SENSOR_CORRECTION"):
                cfg.sensorCorrection = !["off", "false", "no", "0"].contains(value.lowercased())
            case ("gemini", "API_KEY"): cfg.geminiAPIKey = value
            case ("gemini", "MODEL"): cfg.geminiModel = value.isEmpty ? cfg.geminiModel : value
            default: break
            }
        }
        return cfg
    }

    /// บันทึก Gemini API key ลง config.ini — แก้บรรทัด API_KEY ใน [Gemini] ถ้ามีอยู่แล้ว
    /// ไม่มี section ก็ต่อท้ายไฟล์ให้ (ค่าอื่นและ comment ในไฟล์คงเดิม)
    static func saveGeminiKey(_ key: String) throws {
        let text = (try? String(contentsOf: configURL, encoding: .utf8)) ?? defaultFileText
        var lines = text.components(separatedBy: "\n")
        func trimmed(_ i: Int) -> String { lines[i].trimmingCharacters(in: .whitespaces) }
        func keyName(_ i: Int) -> String? {
            guard let eq = lines[i].firstIndex(of: "=") else { return nil }
            return lines[i][..<eq].trimmingCharacters(in: .whitespaces).uppercased()
        }
        let newLine = "API_KEY = \(key)"
        if let start = lines.indices.first(where: { trimmed($0).lowercased() == "[gemini]" }) {
            let end = lines.indices.first(where: { $0 > start && trimmed($0).hasPrefix("[") }) ?? lines.count
            if let k = (start + 1 ..< end).first(where: { keyName($0) == "API_KEY" }) {
                lines[k] = newLine
            } else {
                lines.insert(newLine, at: start + 1)
            }
        } else {
            if let last = lines.last, !last.trimmingCharacters(in: .whitespaces).isEmpty { lines.append("") }
            lines += ["[Gemini]", newLine, "MODEL = gemini-3.8-flash"]
        }
        try lines.joined(separator: "\n").write(to: configURL, atomically: true, encoding: .utf8)
    }
}
