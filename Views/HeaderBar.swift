import SwiftUI

/// แถบบนสุด — ชื่อแอพ serif ทองคำ + สถานะ + สลับหน้า (สไตล์กระจก)
struct HeaderBar: View {
    @ObservedObject var store: WeatherStore

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sun.max.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(Theme.gold)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Argard")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.textGold)
                    Text("v\(AppInfo.version)")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.14)))
                }
                if !store.obs.obsTimeLocal.isEmpty {
                    // "Cloud" แทน "Obs" — ชี้ว่าเป็นข้อมูลจากคลาวด์ weather.com ซึ่งบางทีแคชชุดเดิมไว้ ไม่ใช่เรียลไทม์เสมอ
                    // พร้อม pill บอกอายุข้อมูลเทียบเวลาปัจจุบัน (เขียว=สด เหลือง=หลังแล้วนิดหน่อย แดง=ล้าหลังมาก)
                    HStack(spacing: 6) {
                        Text("Station \(store.config.stationID) • Cloud \(store.obs.obsTimeLocal)")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                        CloudStatusPill(obsTime: store.obs.obsTimeUtc)
                    }
                }
            }

            Spacer()

            if !store.errorMessage.isEmpty {
                Label(store.errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.45))
                    .help(store.errorMessage)
                    .lineLimit(1)
            }

            Picker("", selection: $store.tab) {
                Text("Dashboard").tag(WeatherStore.Tab.dashboard)
                Text("12h Forecast").tag(WeatherStore.Tab.forecast)
            }
            .pickerStyle(.segmented)
            .frame(width: 230)

            Button {
                Task { await store.refresh() }
            } label: {
                ZStack {
                    Circle().fill(.white.opacity(0.08))
                    Circle().strokeBorder(.white.opacity(0.16))
                    if store.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .help("Refresh (⌘R) • auto ทุก \(store.refreshSeconds) วินาที")
            .disabled(store.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
        }
    }
}


/// Pill สถานะความสดของข้อมูลคลาวด์ — เทียบเวลา obs กับตอนนี้
/// ขับด้วย TimelineView ของตัวเอง อายุจะวิ่งสดทุกวินาทีแม้ header ไม่ render ใหม่
struct CloudStatusPill: View {
    let obsTime: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let age = obsTime.map { context.date.timeIntervalSince($0) } ?? -1
            let color: Color = age < 0 ? .gray : (age <= 180 ? .green : (age <= 600 ? .yellow : .red))
            let text: String = {
                if age < 0 { return "—" }
                if age <= 180 { return "LIVE" }
                return "+\(Int(age / 60)) min"
            }()
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(text)
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.35)))
        }
    }
}
