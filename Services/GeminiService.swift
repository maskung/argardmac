import Foundation

/// เรียก Gemini API (generateContent) ผ่าน REST ตรง ๆ — เทียบเท่า
/// client.models.generate_content(model:, contents:, config: system_instruction + temperature)
/// ของ google-genai ใน Python
struct GeminiService {
    let apiKey: String
    let model: String

    enum GeminiError: LocalizedError {
        case http(Int, String)
        case empty(String?)

        /// รุ่นนี้ใช้ไม่ได้ตอนนี้ แต่รุ่นอื่นน่าจะได้ — ไม่ว่าง (5xx), โควต้าของรุ่นนี้หมด (429),
        /// รุ่นถูกปิด (404) หรือไม่ส่งคำตอบมา / key ผิด (400, 403) สลับรุ่นก็ไม่ช่วย
        var shouldTryNextModel: Bool {
            switch self {
            case .http(let code, _): return [404, 429, 500, 502, 503, 504].contains(code)
            case .empty: return true
            }
        }

        var errorDescription: String? {
            switch self {
            case .http(400, let msg) where msg.contains("API key"):
                return "API key ไม่ถูกต้อง — ตรวจ key อีกครั้ง (\(msg))"
            case .http(429, let msg):
                return "ใช้โควต้า Gemini เกินกำหนด ลองใหม่อีกสักครู่ (\(msg))"
            case .http(let code, let msg):
                return "Gemini ตอบกลับ HTTP \(code): \(msg)"
            case .empty(let reason):
                return "Gemini ไม่ได้ส่งคำตอบกลับมา" + (reason.map { " (\($0))" } ?? "")
            }
        }
    }

    func generate(system: String, prompt: String, temperature: Double = 0.3) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var req = URLRequest(url: url, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        req.httpBody = try JSONEncoder().encode(Request(
            systemInstruction: .init(parts: [.init(text: system)]),
            contents: [.init(role: "user", parts: [.init(text: prompt)])],
            generationConfig: .init(temperature: temperature)))

        let (data, resp) = try await URLSession.shared.data(for: req)
        let decoded = try? JSONDecoder().decode(Response.self, from: data)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = decoded?.error?.message ?? String(decoding: data, as: UTF8.self)
            throw GeminiError.http(http.statusCode, msg)
        }
        let candidate = decoded?.candidates?.first
        let text = (candidate?.content?.parts ?? [])
            .filter { $0.thought != true }      // ข้ามส่วน "ความคิด" ของโมเดล (ถ้ามี)
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw GeminiError.empty(candidate?.finishReason ?? decoded?.promptFeedback?.blockReason)
        }
        return text
    }

    // MARK: - รูปแบบ JSON ของ API

    private struct Part: Codable {
        var text: String?
        var thought: Bool?
    }
    private struct Content: Codable {
        var role: String?
        var parts: [Part]?
    }
    private struct Request: Encodable {
        struct GenerationConfig: Encodable { let temperature: Double }
        let systemInstruction: Content
        let contents: [Content]
        let generationConfig: GenerationConfig
    }
    private struct Response: Decodable {
        struct Candidate: Decodable {
            let content: Content?
            let finishReason: String?
        }
        struct Feedback: Decodable { let blockReason: String? }
        struct APIError: Decodable { let message: String? }
        let candidates: [Candidate]?
        let promptFeedback: Feedback?
        let error: APIError?
    }
}
