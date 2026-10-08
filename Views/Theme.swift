import SwiftUI

/// ธีม "หรูหราอลังการ" — พื้นหลังเข้ม + กระจก + ทองคำ
enum Theme {

    // พื้นหลังไล่เฉดเข้ม (น้ำเงินลึก → เขียวน้ำทะเลเข้ม → ม่วงเข้ม)
    static let background = LinearGradient(
        stops: [
            .init(color: Color(red: 0.016, green: 0.027, blue: 0.090), location: 0),
            .init(color: Color(red: 0.035, green: 0.083, blue: 0.170), location: 0.45),
            .init(color: Color(red: 0.080, green: 0.050, blue: 0.160), location: 1.0),
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // ตัวเลข/ข้อความสีทองคำ
    static let textGold = LinearGradient(
        colors: [Color(red: 1.00, green: 0.906, blue: 0.639),
                 Color(red: 0.961, green: 0.663, blue: 0.294)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // ไล่เฉดสำหรับ icon/badge ของแต่ละการ์ด
    static let gold  = LinearGradient(colors: [Color(red: 0.969, green: 0.780, blue: 0.361),
                                               Color(red: 0.941, green: 0.549, blue: 0.180)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    static let fire  = LinearGradient(colors: [Color(red: 1.00, green: 0.420, blue: 0.420),
                                               Color(red: 1.00, green: 0.663, blue: 0.302)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    static let breeze = LinearGradient(colors: [Color(red: 0.184, green: 0.827, blue: 0.769),
                                                Color(red: 0.231, green: 0.788, blue: 0.859)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
    static let rain  = LinearGradient(colors: [Color(red: 0.302, green: 0.671, blue: 0.969),
                                               Color(red: 0.455, green: 0.561, blue: 0.988)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    static let solar = LinearGradient(colors: [Color(red: 1.00, green: 0.831, blue: 0.231),
                                               Color(red: 1.00, green: 0.529, blue: 0.529)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    static let water = LinearGradient(colors: [Color(red: 0.133, green: 0.722, blue: 0.812),
                                               Color(red: 0.298, green: 0.431, blue: 0.961)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mintG = LinearGradient(colors: [Color(red: 0.388, green: 0.902, blue: 0.745),
                                               Color(red: 0.125, green: 0.788, blue: 0.592)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    static let moonGrad = LinearGradient(colors: [Color(red: 0.518, green: 0.353, blue: 0.969),
                                                  Color(red: 0.710, green: 0.525, blue: 0.969)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    static let violet = LinearGradient(colors: [Color(red: 0.855, green: 0.467, blue: 0.949),
                                                Color(red: 0.373, green: 0.239, blue: 0.769)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - สไตล์การ์ดกระจก

extension View {
    /// การ์ดกระจกด้าน + ขอบไล่เฉด + เงา
    func glassCard(corner: CGFloat = 16) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.30), radius: 12, x: 0, y: 6)
    }
}
