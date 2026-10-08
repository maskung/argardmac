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

// MARK: - พยากรณ์รายชั่วโมง (Open-Meteo — ฟรี ไม่ต้องใช้ key)

/// โมเดลกลางสำหรับพยากรณ์รายชั่วโมง ที่ view ใช้ทั้งแอพ
/// (เดิมใช้ของ OpenWeather 3 ชม./จุด — ตอนนี้ map มาจาก Open-Meteo)
struct OWForecastItem {
    var dt: TimeInterval = 0        // epoch seconds
    var temp: Double?
    var feelsLike: Double?
    var pressure: Double?           // hPa
    var humidity: Double?           // %
    var weatherDesc = ""
    var weatherIcon = ""            // เก็บเป็น icon code ของ OpenWeather (ดู WX.weatherEmoji)
    var clouds: Double?             // %
    var windSpeed: Double?          // m/s
    var windDeg: Double?
    var visibility: Double?         // เมตร
    var pop: Double?                // 0...1
    var rain: Double?               // mm ในชั่วโมงนั้น
}

/// คำตอบดิบของ /v1/forecast (timeformat=unixtime)
struct OMForecastResponse: Decodable {
    let hourly: OMHourly?
}

struct OMHourly: Decodable {
    var time: [Double]?
    var temperature: [Double?]?
    var apparentTemperature: [Double?]?
    var humidity: [Double?]?
    var precipProbability: [Double?]?
    var precipitation: [Double?]?
    var weatherCode: [Double?]?
    var cloudCover: [Double?]?
    var visibility: [Double?]?
    var windSpeed: [Double?]?
    var windDirection: [Double?]?
    var pressure: [Double?]?
    var isDay: [Double?]?

    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case humidity = "relative_humidity_2m"
        case precipProbability = "precipitation_probability"
        case precipitation
        case weatherCode = "weather_code"
        case cloudCover = "cloud_cover"
        case visibility
        case windSpeed = "wind_speed_10m"
        case windDirection = "wind_direction_10m"
        case pressure = "pressure_msl"
        case isDay = "is_day"
    }
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
