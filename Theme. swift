import SwiftUI

enum ShinnTheme {
    // Màu nền chính — đen tuyệt đối theo ảnh demo
    static let background = Color(red: 0, green: 0, blue: 0)

    // Màu card — đen nhạt hơn một chút để phân tầng
    static let cardBackground = Color(red: 0.08, green: 0.08, blue: 0.09)

    // Viền neon trắng phát sáng
    static let neonBorder = Color.white.opacity(0.85)

    // Accent trắng
    static let accent = Color.white

    // Chữ chính
    static let primaryText = Color.white

    // Chữ phụ
    static let secondaryText = Color.white.opacity(0.65)

    // Chữ mờ
    static let tertiaryText = Color.white.opacity(0.35)

    // Đỏ cảnh báo
    static let danger = Color(red: 1.0, green: 0.23, blue: 0.19)

    // Xanh thành công
    static let success = Color(red: 0.2, green: 0.85, blue: 0.4)

    // Vàng cảnh báo
    static let warning = Color(red: 1.0, green: 0.75, blue: 0.0)

    // Gradient nền cho Home
    static let homeGradient = LinearGradient(
        colors: [Color(red: 0.02, green: 0.02, blue: 0.03),
                 Color(red: 0, green: 0, blue: 0)],
        startPoint: .top,
        endPoint: .bottom
    )

    // Corner radius chuẩn
    static let cardCornerRadius: CGFloat = 18
    static let buttonCornerRadius: CGFloat = 12
    static let iconCornerRadius: CGFloat = 14

    // Padding
    static let pageInset: CGFloat = 16
    static let cardPadding: CGFloat = 14
}

// Hiệu ứng viền neon phát sáng — dùng cho card gói
struct NeonCardBorder: View {
    var isHighlighted: Bool = false

    var body: some View {
        RoundedRectangle(
            cornerRadius: ShinnTheme.cardCornerRadius,
            style: .continuous
        )
        .strokeBorder(
            LinearGradient(
                colors: isHighlighted
                    ? [Color.white, Color.white.opacity(0.6)]
                    : [Color.white.opacity(0.55), Color.white.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: isHighlighted ? 1.5 : 0.8
        )
        .shadow(
            color: Color.white.opacity(isHighlighted ? 0.45 : 0.18),
            radius: isHighlighted ? 8 : 4
        )
    }
}

// Icon với khung vuông bo góc
struct ShinnIconBox: View {
    let systemName: String
    var size: CGFloat = 28
    var tint: Color = ShinnTheme.accent

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: ShinnTheme.iconCornerRadius,
                style: .continuous
            )
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(
                    cornerRadius: ShinnTheme.iconCornerRadius,
                    style: .continuous
                )
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            Image(systemName: systemName)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

// Logo chữ SHINN H4K dạng crown
struct ShinnLogo: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 6 : 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: compact ? 18 : 26, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.8), radius: 6)

            VStack(alignment: .leading, spacing: 0) {
                Text("SHINN H4K")
                    .font(.system(
                        size: compact ? 18 : 26,
                        weight: .black,
                        design: .default
                    ))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.6), radius: 4)
                if !compact {
                    Text("GAMING CENTER")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(2.5)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}