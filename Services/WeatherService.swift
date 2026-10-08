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
        var c = URLComponents(string: "https://api.openweathermap.org/data/2.5/forecast")
        c?.queryItems = [
            .init(name: "lat", value: String(format: "%.4f", config.latitude)),
            .init(name: "lon", value: String(format: "%.4f", config.longitude)),
            .init(name: "units", value: "metric"),
            .init(name: "appid", value: config.openWeatherAPIKey),
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

    func fetchForecast() async -> ([OWForecastItem], String) {
        guard let url = forecastURL else { return ([], "Bad URL") }
        do {
            let data = try await get(url)
            let resp = try JSONDecoder().decode(OWForecastResponse.self, from: data)
            return (resp.list ?? [], "")
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
