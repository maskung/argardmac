import SwiftUI

/// แถบบนสุด — ชื่อสถานี, เวลา, สถานะ, ปุ่ม refresh, สลับหน้า
struct HeaderBar: View {
    @ObservedObject var store: WeatherStore

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sun.max.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.orange, .yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Argard • \(store.obs.neighborhood.isEmpty ? store.config.stationID : store.obs.neighborhood)")
                    .font(.system(size: 15, weight: .bold))
                if !store.obs.obsTimeLocal.isEmpty {
                    Text("Station \(store.config.stationID) • Obs \(store.obs.obsTimeLocal)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // นาฬิกาเดิน
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date.formatted(.dateTime.hour().minute().second()))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let updated = store.lastUpdated {
                Text("Updated \(updated.formatted(.dateTime.hour().minute().second()))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if !store.errorMessage.isEmpty {
                Label(store.errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
                    .help(store.errorMessage)
                    .lineLimit(1)
            }

            Picker("Page", selection: $store.tab) {
                Text("Dashboard").tag(WeatherStore.Tab.dashboard)
                Text("12h Forecast").tag(WeatherStore.Tab.forecast)
            }
            .pickerStyle(.segmented)
            .frame(width: 230)

            Button {
                Task { await store.refresh() }
            } label: {
                if store.isLoading {
                    ProgressView().controlSize(.small).frame(width: 36, height: 22)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 36, height: 22)
                }
            }
            .help("Refresh (⌘R) • auto ทุก \(store.refreshSeconds) วินาที")
            .disabled(store.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
