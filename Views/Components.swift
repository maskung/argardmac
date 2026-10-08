import SwiftUI

// MARK: - การ์ด (แทน Panel ของ rich)

struct Card<Content: View>: View {
    let title: String
    let systemIcon: String
    var accent: Color = .accentColor
    var badge: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.18), in: Capsule())
                        .foregroundStyle(accent)
                }
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }
}

// MARK: - แถวข้อมูล  label ..... value

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    init(_ label: String, _ value: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(valueColor)
        }
        .font(.system(size: 13))
    }
}

// MARK: - แถบ gauge (แทน ███░░░░ ของ Python)

struct GaugeBar: View {
    let value: Double
    let maxValue: Double
    var tint: Color = .accentColor

    var ratio: Double { min(Swift.max(value / maxValue, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule().fill(tint)
                    .frame(width: geo.size.width * ratio)
            }
        }
        .frame(height: 8)
        .animation(.easeInOut(duration: 0.4), value: ratio)
    }
}
