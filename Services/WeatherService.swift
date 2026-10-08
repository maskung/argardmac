import Foundation

/// ดึงข้อมูลจาก API ทั้ง 3 แหล่ง (Weather.com PWS / OpenWeather / Open-Meteo)
/// คืนค่าเป็น (ข้อมูล, ข้อความ error — ว่าง = สำเร็จ) ตรง style โปรแกรม Python เดิม
struct WeatherService {
    let config: AppConfig
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg)
    }()

    private func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("Argard-macOS/1.2", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "HTTP", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
        return data
    }

    private func errMsg(_ e: Error) -> String {
        (e as NSError).userInfo[NSLocalizedDescriptionKey] as? String ?? e.localizedDescription
    }

    // MARK: URLs

    var observationURL: URL? {
        var c = URLComponents(string: "https://api.weather.com/v2/pws/observations/current")
        c?.queryItems = [
            .init(name: "stationId", value: config.stationID),
            .init(name: "format", value: "json"),
            .init(name: "units", value: "m"),
            .init(name: "apiKey", value: config.weatherComAPIKey),
        ]
        return c?.url
    }

    var forecastURL: URL? {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        c?.queryItems = [
            .init(name: "latitude", value: String(format: "%.4f", config.latitude)),
            .init(name: "longitude", value: String(format: "%.4f", config.longitude)),
            .init(name: "hourly", value: [
                "temperature_2m", "apparent_temperature", "relative_humidity_2m",
                "precipitation_probability", "precipitation", "weather_code",
                "cloud_cover", "visibility", "wind_speed_10m", "wind_direction_10m",
                "pressure_msl", "is_day",
            ].joined(separator: ",")),
            .init(name: "wind_speed_unit", value: "ms"),
            .init(name: "forecast_days", value: "2"),
            .init(name: "timeformat", value: "unixtime"),
            .init(name: "timezone", value: "auto"),
        ]
        return c?.url
    }

    var airQualityURL: URL? {
        var c = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")
        c?.queryItems = [
            .init(name: "latitude", value: String(format: "%.4f", config.latitude)),
            .init(name: "longitude", value: String(format: "%.4f", config.longitude)),
            .init(name: "current", value: "us_aqi,pm2_5,pm10,ozone,nitrogen_dioxide"),
            .init(name: "timezone", value: "auto"),
        ]
        return c?.url
    }

    // MARK: Fetch

    func fetchObservation() async -> (PWSObservation, String) {
        guard let url = observationURL else { return (PWSObservation(), "Bad URL") }
        do {
            let data = try await get(url)
            let resp = try JSONDecoder().decode(PWSObservationResponse.self, from: data)
            if let obs = resp.observations?.first { return (obs, "") }
            return (PWSObservation(), "No observations")
        } catch {
            return (PWSObservation(), errMsg(error))
        }
    }

    /// พยากรณ์รายชั่วโมงจาก Open-Meteo — ตัดเหลือชั่วโมงปัจจุบันถึง +24 ชม.
    func fetchForecast() async -> ([OWForecastItem], String) {
        guard let url = forecastURL else { return ([], "Bad URL") }
        do {
            let data = try await get(url)
            let resp = try JSONDecoder().decode(OMForecastResponse.self, from: data)
            guard let h = resp.hourly, let times = h.time else { return ([], "No hourly data") }
            let cutoff = Date().addingTimeInterval(-90 * 60).timeIntervalSince1970

            var items: [OWForecastItem] = []
            for (i, t) in times.enumerated() {
                guard t >= cutoff else { continue }
                func at(_ arr: [Double?]?, _ i: Int) -> Double? {
                    guard let arr, i < arr.count else { return nil }
                    return arr[i]
                }
                let wmo = WX.wmo(at(h.weatherCode, i), isDay: (at(h.isDay, i) ?? 1) == 1)
                items.append(OWForecastItem(
                    dt: t,
                    temp: at(h.temperature, i),
                    feelsLike: at(h.apparentTemperature, i),
                    pressure: at(h.pressure, i),
                    humidity: at(h.humidity, i),
                    weatherDesc: wmo.desc,
                    weatherIcon: wmo.icon,
                    clouds: at(h.cloudCover, i),
                    windSpeed: at(h.windSpeed, i),
                    windDeg: at(h.windDirection, i),
                    visibility: at(h.visibility, i),
                    pop: at(h.precipProbability, i).map { $0 / 100.0 },
                    rain: at(h.precipitation, i)
                ))
                if items.count >= 24 { break }
            }
            return (items, items.isEmpty ? "No upcoming hours" : "")
        } catch {
            return ([], errMsg(error))
        }
    }

    func fetchAirQuality() async -> (AQCurrent, String) {
        guard let url = airQualityURL else { return (AQCurrent(), "Bad URL") }
        do {
            let data = try await get(url)
            let resp = try JSONDecoder().decode(AQResponse.self, from: data)
            return (resp.current ?? AQCurrent(), "")
        } catch {
            return (AQCurrent(), errMsg(error))
        }
    }
}
