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
            default: break
            }
        }
        return cfg
    }
}
