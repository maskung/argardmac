import SwiftUI
import AppKit

/// หน้า Agriculture — วิเคราะห์อากาศเพื่อการพ่นยาด้วย Gemini
/// ซ้าย: ค่าจากสถานีที่จะส่งไป + รายละเอียดการพ่น + ปุ่มวิเคราะห์ / ขวา: คำตอบจาก Gemini
struct AgricultureView: View {
    @ObservedObject var store: WeatherStore
    @ObservedObject var advisor: SprayAdvisor

    @State private var draftKey = ""
    @State private var editingKey = false
    @State private var keySaveError = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("AGRICULTURE • วิเคราะห์อากาศเพื่อการพ่นยา")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(Theme.textGold)

                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 14) {
                        stationCard
                        planCard
                        if !advisor.hasAPIKey || editingKey {
                            apiKeyCard
                        }
                        analyzeButton
                        if advisor.hasAPIKey && !editingKey {
                            keyStatusRow
                        }
                    }
                    .frame(width: 440)

                    resultCard
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
    }

    // MARK: - ค่าจากสถานี (ส่งให้ Gemini ตอนกดปุ่ม)

    private var stationCard: some View {
        let o = store.obs
        let m = o.metric
        let badge = o.obsTimeUtc.map { "วัดเมื่อ " + SprayAdvisor.thaiTimeText($0) }
        let tiles: [(String, String)] = [
            ("🌡️ อุณหภูมิ", WX.fmt(m.temp, suffix: " °C")),
            ("💧 ความชื้น", WX.fmtInt(o.humidity, suffix: " %")),
            ("🫧 จุดน้ำค้าง", WX.fmt(m.dewpt, suffix: " °C")),
            ("💨 ลม", WX.fmt(m.windSpeed, suffix: " km/h")),
            ("🌪️ ลมกระโชก", WX.fmt(m.windGust, suffix: " km/h")),
            ("🧭 ทิศลม", o.winddir.map { "\(WX.degToCompass($0)) \(Int($0))°" } ?? "-"),
            ("🌧️ ฝนขณะนี้", WX.fmt(m.precipRate, 2, suffix: " mm/h")),
            ("📅 ฝนวันนี้", WX.fmt(m.precipTotal, suffix: " mm")),
            ("☀️ แสงแดด", WX.fmtInt(o.solarRadiation, suffix: " W/m²")),
        ]
        return Card(title: "ข้อมูลจากสถานี", systemIcon: "antenna.radiowaves.left.and.right",
                    accent: Theme.mintG, badge: badge, minHeight: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                      spacing: 8) {
                ForEach(tiles, id: \.0) { tile in
                    StatTile(label: tile.0, value: tile.1)
                }
            }
            Text("ส่งค่าเหล่านี้ + UV + ความกดอากาศ + พยากรณ์ 6 ชม.ข้างหน้า ให้ Gemini")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - รายละเอียดการพ่น

    private var planCard: some View {
        Card(title: "รายละเอียดการพ่น", systemIcon: "leaf.fill",
             accent: Theme.breeze, minHeight: 0) {
            field("พืช") {
                HStack(spacing: 8) {
                    Picker("", selection: $advisor.crop) {
                        ForEach(SprayAdvisor.cropPresets, id: \.self) { Text($0).tag($0) }
                        Divider()
                        Text(SprayAdvisor.otherCrop).tag(SprayAdvisor.otherCrop)
                    }
                    .labelsHidden()
                    .fixedSize()
                    if advisor.crop == SprayAdvisor.otherCrop {
                        TextField("ชื่อพืช เช่น มะม่วง", text: $advisor.customCrop)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            field("สารที่จะพ่น (เลือกได้หลายอย่าง)") {
                HStack(spacing: 16) {
                    ForEach(SprayAdvisor.SprayType.allCases) { type in
                        Toggle(type.label, isOn: sprayBinding(type))
                            .toggleStyle(.checkbox)
                    }
                }
                .font(.system(size: 13))
                if advisor.sprayTypes.isEmpty {
                    Text("เลือกอย่างน้อย 1 อย่าง")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }
            field("จะพ่นเมื่อไร") {
                Picker("", selection: $advisor.timing) {
                    ForEach(SprayAdvisor.Timing.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            field("หมายเหตุ (ไม่บังคับ)") {
                TextField("เช่น เพลี้ยไฟระบาด, ใช้สารดูดซึม, ใบอ่อนกำลังแตก", text: $advisor.note)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    /// ผูกเช็คบ็อกซ์ของสารแต่ละอย่างกับชุดที่เลือก
    private func sprayBinding(_ type: SprayAdvisor.SprayType) -> Binding<Bool> {
        Binding(
            get: { advisor.sprayTypes.contains(type) },
            set: { on in
                if on { advisor.sprayTypes.insert(type) } else { advisor.sprayTypes.remove(type) }
            })
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ control: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            control()
        }
    }

    // MARK: - ปุ่มวิเคราะห์

    private var analyzeButton: some View {
        Button {
            Task { await advisor.analyze(store: store) }
        } label: {
            HStack(spacing: 8) {
                if advisor.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(advisor.isLoading ? "Gemini กำลังวิเคราะห์..."
                                       : "วิเคราะห์อากาศเพื่อการพ่น\(advisor.sprayButtonText)")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Theme.mintG, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color(red: 0.125, green: 0.788, blue: 0.592).opacity(0.4), radius: 8, y: 3)
            .opacity(canAnalyze ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(advisor.isLoading || !canAnalyze)
        .keyboardShortcut(.return, modifiers: .command)
    }

    private var canAnalyze: Bool { advisor.hasAPIKey && !advisor.sprayTypes.isEmpty }

    // MARK: - Gemini API key

    private var apiKeyCard: some View {
        Card(title: "Gemini API Key", systemIcon: "key.fill",
             accent: Theme.violet, minHeight: 0) {
            SecureField("วาง API key ที่นี่", text: $draftKey)
                .textFieldStyle(.roundedBorder)
                .onSubmit(saveKey)
            HStack {
                Link("ขอ key ฟรีที่ Google AI Studio ↗",
                     destination: URL(string: "https://aistudio.google.com/apikey")!)
                    .font(.system(size: 11))
                Spacer()
                if editingKey {
                    Button("ยกเลิก") { editingKey = false; draftKey = "" }
                }
                Button("บันทึก", action: saveKey)
                    .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text(keySaveError.isEmpty ? "เก็บไว้ใน config.ini ร่วมกับ API key อื่นของแอพ" : keySaveError)
                .font(.system(size: 11))
                .foregroundStyle(keySaveError.isEmpty ? .white.opacity(0.45) : .red)
        }
    }

    private var keyStatusRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            Text("Gemini API key พร้อมใช้ • \(advisor.model)")
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
            Button("เปลี่ยน key") { editingKey = true }
                .buttonStyle(.link)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 4)
    }

    private func saveKey() {
        let k = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        do {
            try advisor.saveAPIKey(k)
            draftKey = ""
            editingKey = false
            keySaveError = ""
        } catch {
            keySaveError = "บันทึกไม่สำเร็จ: \(error.localizedDescription)"
        }
    }

    // MARK: - ผลวิเคราะห์

    private var resultCard: some View {
        Card(title: "ผลวิเคราะห์จาก Gemini", systemIcon: "sparkles",
             accent: Theme.violet, badge: verdictBadge, minHeight: 0) {
            if advisor.isLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(advisor.retryNote.isEmpty ? "กำลังส่งข้อมูลสถานีให้ Gemini วิเคราะห์..."
                                                   : advisor.retryNote)
                        .foregroundStyle(advisor.retryNote.isEmpty ? .white.opacity(0.7) : .orange)
                }
                .font(.system(size: 13))
                .padding(.vertical, 20)
            } else if !advisor.errorText.isEmpty {
                Label(advisor.errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.5))
                    .textSelection(.enabled)
            } else if !advisor.answer.isEmpty {
                GeminiAnswerText(text: advisor.answer)
                Divider().overlay(.white.opacity(0.12))
                answerFooter
            } else {
                placeholder
            }
            if !advisor.lastPrompt.isEmpty {
                DisclosureGroup("ข้อความที่ส่งให้ Gemini") {
                    Text(advisor.lastPrompt)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.mintG)
            Text("กดปุ่ม \"วิเคราะห์อากาศเพื่อการพ่น\(advisor.sprayButtonText)\"")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("Gemini จะประเมินจากค่าสถานีล่าสุดว่าตอนนี้เหมาะจะพ่นหรือไม่ พร้อมเหตุผล")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var answerFooter: some View {
        HStack(spacing: 8) {
            Group {
                if let t = advisor.dataTime {
                    Text("ข้อมูลสถานี \(SprayAdvisor.thaiTimeText(t))")
                }
                if let t = advisor.askedAt {
                    Text("• วิเคราะห์ \(SprayAdvisor.thaiTimeText(t))")
                }
                Text("• \(advisor.model)")
            }
            .foregroundStyle(.white.opacity(0.45))
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(advisor.answer, forType: .string)
            } label: {
                Label("คัดลอก", systemImage: "doc.on.doc")
            }
            .buttonStyle(.link)
        }
        .font(.system(size: 11))
    }

    /// สรุปผลจากสัญลักษณ์บรรทัดแรกที่สั่งให้ Gemini ขึ้นต้นไว้
    private var verdictBadge: String? {
        guard !advisor.isLoading, let first = advisor.answer.split(separator: "\n").first else { return nil }
        if first.contains("✅") { return "✅ เหมาะพ่น" }
        if first.contains("⚠️") { return "⚠️ ระวัง" }
        if first.contains("❌") { return "❌ ไม่ควรพ่น" }
        return nil
    }
}

/// ช่องแสดงค่าเล็ก ๆ: ชื่อค่า + ตัวเลข
private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// แสดงคำตอบ Markdown ของ Gemini แบบง่าย: หัวข้อ (#), รายการ (* / -), ตัวหนา/เอียงในบรรทัด
struct GeminiAnswerText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, raw in
                line(raw.trimmingCharacters(in: .whitespaces))
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(.white.opacity(0.9))
        .lineSpacing(3)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func line(_ s: String) -> some View {
        if s.isEmpty {
            Spacer().frame(height: 2)
        } else if s.hasPrefix("#") {
            inline(String(s.drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespaces))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
        } else if s.hasPrefix("* ") || s.hasPrefix("- ") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").foregroundStyle(Theme.mintG)
                inline(String(s.dropFirst(2)))
            }
        } else {
            inline(s)
        }
    }

    private func inline(_ s: String) -> Text {
        let attr = try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        return Text(attr ?? AttributedString(s))
    }
}
