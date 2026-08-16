import SwiftUI
import UIKit

/// Design tokens for Tablo. Views reach for these names, never a one-off hex.
struct Palette {
    let bg: Color
    let card: Color
    let ink: Color
    let muted: Color
    let faint: Color
    let line: Color
    let track: Color
    let accent: Color
    let accentGlow: Color

    static let light = Palette(
        bg: Color(hex: "F6F1EA"),
        card: Color(hex: "FFFCF8"),
        ink: Color(hex: "2A2622"),
        muted: Color(hex: "7A736B"),
        faint: Color(hex: "B7AEA4"),
        line: Color(hex: "2A2622").opacity(0.10),
        track: Color(hex: "2A2622").opacity(0.06),
        accent: Color(hex: "E45A24"),
        accentGlow: Color(hex: "E45A24").opacity(0.22)
    )

    static let dark = Palette(
        bg: Color(hex: "141820"),
        card: Color(hex: "1E2430"),
        ink: Color(hex: "F3ECE4"),
        muted: Color(hex: "A39A90"),
        faint: Color(hex: "6E675F"),
        line: Color(hex: "F3ECE4").opacity(0.10),
        track: Color(hex: "F3ECE4").opacity(0.10),
        accent: Color(hex: "F07A42"),
        accentGlow: Color(hex: "F07A42").opacity(0.24)
    )

    static func current(for scheme: ColorScheme) -> Palette {
        scheme == .dark ? .dark : .light
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .light
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

enum Layout {
    static let screenInset: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let stackSpacing: CGFloat = 16
    static let cardRadius: CGFloat = 20
    static let controlRadius: CGFloat = 16
    static let mediaRadiusSmall: CGFloat = 12
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

private struct KickerText: ViewModifier {
    @Environment(\.palette) private var palette
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .medium))
            .textCase(.uppercase)
            .tracking(1.8)
            .foregroundStyle(palette.muted)
    }
}

private struct DisplayTitleText: ViewModifier {
    @Environment(\.palette) private var palette
    func body(content: Content) -> some View {
        content
            .font(.system(size: 28, weight: .light))
            .tracking(-0.6)
            .foregroundStyle(palette.ink)
    }
}

private struct BodyText: ViewModifier {
    @Environment(\.palette) private var palette
    var muted: Bool = false
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(muted ? palette.muted : palette.ink)
    }
}

private struct CaptionText: ViewModifier {
    @Environment(\.palette) private var palette
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(palette.muted)
    }
}

extension View {
    func kickerStyle() -> some View { modifier(KickerText()) }
    func displayTitleStyle() -> some View { modifier(DisplayTitleText()) }
    func bodyStyle(muted: Bool = false) -> some View { modifier(BodyText(muted: muted)) }
    func captionStyle() -> some View { modifier(CaptionText()) }
}

struct SanctuaryBackground: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            palette.bg
            GeometryReader { geo in
                EllipticalGradient(
                    gradient: Gradient(colors: [palette.accentGlow, Color.clear]),
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.55
                )
                .frame(width: geo.size.width * 1.2, height: geo.size.height * 0.7)
                .position(x: geo.size.width * 0.5, y: geo.size.height * -0.06)
            }
        }
        .ignoresSafeArea()
    }
}

struct PaletteProvider<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        let palette = Palette.current(for: colorScheme)
        content()
            .environment(\.palette, palette)
            .tint(palette.accent)
    }
}

extension Color {
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double((value >> 0) & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
