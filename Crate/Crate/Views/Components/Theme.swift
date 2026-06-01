import SwiftUI

/// Design tokens from `стили/45-33-identity-styles.md`.
/// Keep app UI tokens separate from generated showcase-card styles.
enum AppTheme {
    static let bg          = Color(light: "#F3E7CF", dark: "#211D18")
    static let bgDeep      = Color(light: "#E7D6B8", dark: "#191510")
    static let panel       = Color(light: "#FFF7E7", dark: "#2D2820")
    static let panelLine   = Color(light: "#D8B98B", dark: "#3D362B")
    static let rowLine     = Color(light: "#E5CEAA", dark: "#322C23")

    static let ink         = Color(light: "#2B2118", dark: "#EAD9B6")
    static let inkSoft     = Color(light: "#4A3728", dark: "#D8CFBF")
    static let inkMuted    = Color(light: "#725A42", dark: "#9A8F78")
    static let inkFaint    = Color(light: "#9B7A55", dark: "#8A7F6A")

    static let gold        = Color(light: "#A45D35", dark: "#C98F3C")
    static let goldSoft    = Color(light: "#C68C5A", dark: "#B88A4A")
    static let ok          = Color(light: "#587D45", dark: "#7FA86A")
    static let warn        = Color(light: "#B45F45", dark: "#C97A5A")

    static let green       = ok
    static let red         = warn

    static let cornerCard: CGFloat = 14
    static let cornerPanel: CGFloat = 16
}

extension Color {
    init(light: String, dark: String) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light) ?? .clear
        })
    }

    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

private extension UIColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&rgb) else { return nil }
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255,
            blue: CGFloat(rgb & 0x0000FF) / 255,
            alpha: 1
        )
    }
}

extension View {
    func feltPanel() -> some View {
        self
            .padding(16)
            .background(AppTheme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerPanel)
                    .stroke(AppTheme.panelLine, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerPanel))
    }

    func crateBackground() -> some View {
        self.background(AppTheme.bg.ignoresSafeArea())
    }
}

struct GoldChip: View {
    let text: String
    let active: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(active ? AppTheme.bg : AppTheme.inkMuted)
            .background(active ? AppTheme.gold : .clear)
            .overlay(
                Capsule().stroke(active ? AppTheme.gold : AppTheme.panelLine, lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

struct SpeedMark45_33: View {
    let showText: Bool

    init(showText: Bool = true) {
        self.showText = showText
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary, lineWidth: 2.4)

            VStack(spacing: 7) {
                Rectangle()
                    .frame(width: 2.4, height: 8)
                    .clipShape(Capsule())

                if showText {
                    VStack(spacing: -1) {
                        Text("45")
                        Text("33")
                    }
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                }

                Rectangle()
                    .frame(width: 2.4, height: 8)
                    .clipShape(Capsule())
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
