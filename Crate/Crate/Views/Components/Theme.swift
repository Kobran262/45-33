import SwiftUI

/// Design tokens from `стили/45-33-identity-styles.md`.
/// Keep app UI tokens separate from generated showcase-card styles.
enum AppTheme {
    static let bg          = Color(hex: "#211D18")
    static let bgDeep      = Color(hex: "#191510")
    static let panel       = Color(hex: "#2D2820")
    static let panelLine   = Color(hex: "#3D362B")
    static let rowLine     = Color(hex: "#322C23")

    static let ink         = Color(hex: "#EAD9B6")
    static let inkSoft     = Color(hex: "#D8CFBF")
    static let inkMuted    = Color(hex: "#9A8F78")
    static let inkFaint    = Color(hex: "#8A7F6A")

    static let gold        = Color(hex: "#C98F3C")
    static let goldSoft    = Color(hex: "#B88A4A")
    static let ok          = Color(hex: "#7FA86A")
    static let warn        = Color(hex: "#C97A5A")

    static let green       = ok
    static let red         = warn

    static let cornerCard: CGFloat = 14
    static let cornerPanel: CGFloat = 16
}

extension Color {
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
