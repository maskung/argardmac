import SwiftUI

// MARK: - การ์ด (แทน Panel ของ rich) — สไตล์กระจกหรูหรา

struct Card<Content: View>: View {
    let title: String
    let systemIcon: String
    var accent: Gradient = Theme.gold
    var badge: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 1, y: 0.5)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accent, in: Capsule())
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

// MARK: - แถวข้อมูล  label ..... value

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white

    init(_ label: String, _ value: String, valueColor: Color = .white) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 8)
            Text(value)
                .monospacedDigit()
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
        .font(.system(size: 13))
    }
}

// MARK: - แถบ gauge เรืองแสง (แทน ███░░░░ ของ Python)

struct GaugeBar: View {
    let value: Double
    let maxValue: Double
    var tint: Color = .orange

    var ratio: Double { min(Swift.max(value / maxValue, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.65), tint],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * ratio)
                    .shadow(color: tint.opacity(0.7), radius: 5)
            }
        }
        .frame(height: 8)
        .animation(.easeInOut(duration: 0.4), value: ratio)
    }
}
