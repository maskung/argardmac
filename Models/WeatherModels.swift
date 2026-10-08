import Foundation

// MARK: - ตัวช่วย decode ค่าที่อาจเป็น null ใน JSON (Weather.com ชอบส่ง null)

extension KeyedDecodingContainer {
    /// Double ที่ยอมรับ null / string / หายไป → nil
    func flexibleDouble(_ key: Key) -> Double? {
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Double(s) }
        return nil
    }
    func flexibleInt(_ key: Key) -> Int? {
        flexibleDouble(key).map { Int($0) }
    }
}

// MARK: - Weather.com PWS (สถานีอากาศส่วนตัว)

struct PWSObservationResponse: Decodable {
    let observations: [PWSObservation]?
}

struct PWSObservation: Decodable {
    var stationID = ""
    var obsTimeLocal = ""
    var neighborhood = ""
    var lat: Double?
    var lon: Double?
    var winddir: Double?
    var uv: Double?
    var solarRadiation: Double?
    var humidity: Double?
    var metric = PWSMetric()

    enum CodingKeys: String, CodingKey {
        case stationID, obsTimeLocal, neighborhood, lat, lon, winddir
        case uv, solarRadiation, humidity, metric
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stationID = (try? c.decodeIfPresent(String.self, forKey: .stationID)) ?? ""
        obsTimeLocal = (try? c.decodeIfPresent(String.self, forKey: .obsTimeLocal)) ?? ""
        neighborhood = (try? c.decodeIfPresent(String.self, forKey: .neighborhood)) ?? ""
        lat = c.flexibleDouble(.lat)
        lon = c.flexibleDouble(.lon)
        winddir = c.flexibleDouble(.winddir)
        uv = c.flexibleDouble(.uv)
        solarRadiation = c.flexibleDouble(.solarRadiation)
        humidity = c.flexibleDouble(.humidity)
        metric = (try? c.decodeIfPresent(PWSMetric.self, forKey: .metric)) ?? PWSMetric()
    }
}

struct PWSMetric: Decodable {
    var temp: Double?
    var heatIndex: Double?
    var dewpt: Double?
    var windChill: Double?
    var windSpeed: Double?      // m/s
    var windGust: Double?       // m/s
    var precipRate: Double?     // mm/h
    var precipTotal: Double?    // mm
    var pressure: Double?       // hPa

    enum CodingKeys: String, CodingKey {
        case temp, heatIndex, dewpt, windChill, windSpeed, windGust
        case precipRate, precipTotal, pressure
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        temp = c.flexibleDouble(.temp); heatIndex = c.flexibleDouble(.heatIndex)
        dewpt = c.flexibleDouble(.dewpt); windChill = c.flexibleDouble(.windChill)
        windSpeed = c.flexibleDouble(.windSpeed); windGust = c.flexibleDouble(.windGust)
        precipRate = c.flexibleDouble(.precipRate); precipTotal = c.flexibleDouble(.precipTotal)
        pressure = c.flexibleDouble(.pressure)
    }
}

// MARK: - OpenWeather 2.5 forecast (ทุก 3 ชม. 40 จุด)

struct OWForecastResponse: Decodable {
    let list: [OWForecastItem]?
}

struct OWForecastItem: Decodable {
    var dt: TimeInterval = 0
    var temp: Double?
    var feelsLike: Double?
    var pressure: Double?
    var humidity: Double?
    var weatherMain = ""
    var weatherDesc = ""
    var weatherIcon = ""
    var clouds: Double?
    var windSpeed: Double?     // m/s
    var windDeg: Double?
    var visibility: Double?    // เมตร
    var pop: Double?           // 0...1
    var rain3h: Double?        // mm

    enum CodingKeys: String, CodingKey {
        case dt, main, weather, clouds, wind, visibility, pop, rain
    }
    enum MainKeys: String, CodingKey { case temp, feels_like, pressure, humidity }
    enum WindKeys: String, CodingKey { case speed, deg }
    enum CloudKeys: String, CodingKey { case all }
    enum RainKeys: String, CodingKey { case h3 = "3h" }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dt = c.flexibleDouble(.dt) ?? 0
        if let mc = try? c.nestedContainer(keyedBy: MainKeys.self, forKey: .main) {
            temp = mc.flexibleDouble(.temp)
            feelsLike = mc.flexibleDouble(.feels_like)
            pressure = mc.flexibleDouble(.pressure)
            humidity = mc.flexibleDouble(.humidity)
        }
        if let wc = try? c.decodeIfPresent([WeatherBit].self, forKey: .weather), let first = wc.first {
            weatherMain = first.main ?? ""
            weatherDesc = first.description ?? ""
            weatherIcon = first.icon ?? ""
        }
        if let cc = try? c.nestedContainer(keyedBy: CloudKeys.self, forKey: .clouds) {
            clouds = cc.flexibleDouble(.all)
        }
        if let wnc = try? c.nestedContainer(keyedBy: WindKeys.self, forKey: .wind) {
            windSpeed = wnc.flexibleDouble(.speed)
            windDeg = wnc.flexibleDouble(.deg)
        }
        visibility = c.flexibleDouble(.visibility)
        pop = c.flexibleDouble(.pop)
        if let rc = try? c.nestedContainer(keyedBy: RainKeys.self, forKey: .rain) {
            rain3h = rc.flexibleDouble(.h3)
        }
    }
}

struct WeatherBit: Decodable {
    let main: String?
    let description: String?
    let icon: String?
}

// MARK: - Open-Meteo Air Quality

struct AQResponse: Decodable {
    let current: AQCurrent?
}

struct AQCurrent: Decodable {
    var usAqi: Double?
    var pm25: Double?
    var pm10: Double?
    var ozone: Double?
    var no2: Double?

    enum CodingKeys: String, CodingKey {
        case usAqi = "us_aqi", pm25 = "pm2_5", pm10, ozone
        case no2 = "nitrogen_dioxide"
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        usAqi = c.flexibleDouble(.usAqi)
        pm25 = c.flexibleDouble(.pm25)
        pm10 = c.flexibleDouble(.pm10)
        ozone = c.flexibleDouble(.ozone)
        no2 = c.flexibleDouble(.no2)
    }
}
