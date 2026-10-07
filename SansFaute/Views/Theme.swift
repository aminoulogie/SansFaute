import SwiftUI
import UIKit

// Design: a French exercise book.
// Ruled paper, ink-blue handwriting, a red margin and the teacher's red pen for corrections.
// Headings in a serif (New York), numbers in rounded digits, body in the system face.

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

enum Theme {
    static let paper = Color(light: 0xF5F4EF, dark: 0x0E1220)
    static let card = Color(light: 0xFFFFFF, dark: 0x181E30)
    static let cardRaised = Color(light: 0xFBFAF6, dark: 0x1F2740)
    static let rule = Color(light: 0xD7E1F2, dark: 0x1C2540)
    static let margin = Color(light: 0xE8A3A6, dark: 0x5A2A33)
    static let ink = Color(light: 0x21458F, dark: 0x8FB0F2)
    static let inkSoft = Color(light: 0xE6ECF8, dark: 0x22305A)
    static let pen = Color(light: 0xC8323A, dark: 0xFF7A7F)
    static let penSoft = Color(light: 0xFBE8E8, dark: 0x3D1F27)
    static let good = Color(light: 0x23804F, dark: 0x5FD394)
    static let goodSoft = Color(light: 0xE4F3EA, dark: 0x16352A)
    static let warn = Color(light: 0xC77A0A, dark: 0xF2B655)
    static let violet = Color(light: 0x6B3FA0, dark: 0xC0A0F0)
    static let muted = Color(light: 0x6B7088, dark: 0x9AA0B8)
    static let stroke = Color(light: 0xE4E3DC, dark: 0x2A3350)

    static func levelColor(_ level: String) -> Color {
        switch level {
        case "C2": return violet
        case "C1": return ink
        default: return Color(light: 0x2F7C86, dark: 0x6CC9D3)
        }
    }

    static func scoreColor(_ score: Int) -> Color {
        switch score {
        case 600...: return violet
        case 500..<600: return good
        case 400..<500: return warn
        default: return pen
        }
    }

    static func ratioColor(_ r: Double) -> Color {
        r >= 0.8 ? good : (r >= 0.6 ? warn : pen)
    }
}

// MARK: - Typography

extension Font {
    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif).weight(weight)
    }
    static func number(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

// MARK: - Backgrounds

/// Exercise-book paper: faint blue rules and a red margin line.
struct RuledPaper: View {
    var showMargin = true
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Theme.paper
                Path { p in
                    var y: CGFloat = 32
                    while y < geo.size.height {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        y += 32
                    }
                }
                .stroke(Theme.rule.opacity(0.55), lineWidth: 0.6)
                if showMargin {
                    Rectangle().fill(Theme.margin.opacity(0.7)).frame(width: 1.2)
                        .offset(x: 10)
                }
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Standard screen background.
    func paperBackground(margin: Bool = true) -> some View {
        background(RuledPaper(showMargin: margin))
    }

    func card(padding: CGFloat = 16, fill: Color = Theme.card) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.stroke, lineWidth: 0.8))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    /// For Lists and Forms: hide the default grey and show the paper.
    func paperList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(RuledPaper())
    }
}

// MARK: - Components

struct LevelBadge: View {
    let level: String
    var body: some View {
        Text(level)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundColor(Theme.levelColor(level))
            .background(Theme.levelColor(level).opacity(0.13), in: Capsule())
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.muted
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.1)
            .foregroundColor(color)
    }
}

struct SectionHeader: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Eyebrow(text: eyebrow)
            Text(title).font(.serif(.title3))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var color: Color = Theme.ink
    var track: Color = Theme.inkSoft

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(max(0.001, min(1, progress))))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
        }
    }
}

struct IconBadge: View {
    let symbol: String
    var color: Color = Theme.ink
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundColor(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

/// A tappable tile for quick actions.
struct Tile: View {
    let symbol: String
    let title: String
    let subtitle: String
    var color: Color = Theme.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IconBadge(symbol: symbol, color: color, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                Text(subtitle).font(.caption).foregroundColor(Theme.muted).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .card(padding: 14)
    }
}

/// A full-width row card with icon, title, subtitle and a chevron.
struct RowCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    var color: Color = Theme.ink
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold)).foregroundColor(.primary)
                Text(subtitle).font(.caption).foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let t = trailing {
                Text(t).font(.number(15, weight: .semibold)).foregroundColor(color)
            }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(Theme.muted.opacity(0.6))
        }
        .card(padding: 14)
    }
}

struct InkButtonStyle: ButtonStyle {
    var color: Color = Theme.ink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var color: Color = Theme.ink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(configuration.isPressed ? 0.2 : 0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Press feedback for cards wrapped in NavigationLink or Button.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ScoreBar: View {
    let label: String
    let score: Int?
    let start: Int
    let target: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.subheadline.weight(.medium))
                Spacer()
                if let s = score {
                    Text("\(s)").font(.number(17)).foregroundColor(Theme.scoreColor(s))
                    LevelBadge(level: Level.cefr(s))
                } else {
                    Text("départ \(start)").font(.caption).foregroundColor(Theme.muted)
                }
            }
            GeometryReader { geo in
                let w = geo.size.width
                let value = score ?? start
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.inkSoft)
                    Capsule().fill(Theme.scoreColor(value).opacity(score == nil ? 0.35 : 1))
                        .frame(width: max(6, w * CGFloat(min(699, value)) / 699.0))
                    Rectangle().fill(Theme.muted.opacity(0.5)).frame(width: 1, height: 14)
                        .offset(x: w * 500.0 / 699.0)
                    Rectangle().fill(Theme.muted.opacity(0.5)).frame(width: 1, height: 14)
                        .offset(x: w * 600.0 / 699.0)
                    Circle().fill(Theme.card).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                        .offset(x: w * CGFloat(target) / 699.0 - 5)
                }
            }
            .frame(height: 10)
            HStack {
                Text("objectif \(target)").font(.caption2).foregroundColor(Theme.muted)
                Spacer()
                Text("C1 500 · C2 600").font(.caption2).foregroundColor(Theme.muted)
            }
        }
    }
}

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

/// A short burst of paper confetti for a perfect score.
struct ConfettiPiece {
    let x = Double.random(in: 0...1)
    let speed = Double.random(in: 0.5...1.2)
    let spin = Double.random(in: -6...6)
    let color = Int.random(in: 0...3)
    let size = Double.random(in: 5...10)
}

struct Confetti: View {
    @State private var start = Date()
    @State private var pieces: [ConfettiPiece] = (0..<70).map { _ in ConfettiPiece() }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSince(start)
                let colors: [Color] = [Theme.ink, Theme.pen, Theme.good, Theme.warn]
                for p in pieces {
                    let y = -20 + t * 260 * p.speed
                    if y > size.height + 20 { continue }
                    let x = p.x * size.width + sin(t * 3 + p.spin) * 18
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(t * p.spin))
                    c.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)),
                           with: .color(colors[p.color]))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
