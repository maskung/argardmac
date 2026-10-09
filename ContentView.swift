import SwiftUI

struct ContentView: View {
    @ObservedObject var store: WeatherStore

    var body: some View {
        // Live: ประเมินใหม่ทุก 1 วิ — ให้ header/การ์ด/banner ทุกส่วนอ่านค่าจาก store
        // ตรง ๆ เสมอ ไม่ขึ้นกับ objectWillChange อย่างเดียว (ดู comment ใน Live)
        Live {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    HeaderBar(store: store)
                    // แถบแจ้ง error ของ API (เงียบมาก่อน — ตอนนี้ให้เห็นชัด ๆ พร้อมปุ่มลองใหม่)
                    if !store.errorMessage.isEmpty {
                        errorBanner
                    }
                    if store.lastUpdated == nil {
                        // โหลดรอบแรกยังไม่เสร็จ — แสดงสถานะกำลังเชื่อมต่อแทนหน้าว่าง 0°
                        VStack(spacing: 14) {
                            ProgressView()
                                .scaleEffect(1.6)
                            Text("กำลังเชื่อมต่อสถานีอากาศ...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Group {
                            switch store.tab {
                            case .dashboard: DashboardView(store: store)
                            case .forecast: ForecastView(store: store)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        // ล็อคธีมเข้มให้เข้ากับดีไซน์หรูหรา
        .preferredColorScheme(.dark)
        .frame(minWidth: 1000, minHeight: 720)
        .task {
            await store.refresh()
            store.startAutoRefresh()
            store.bindLifecycleRefresh()
        }
    }

    private var errorBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(store.errorMessage)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                Task { await store.refresh() }
            } label: {
                Text("ลองใหม่")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.red.opacity(0.35))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
