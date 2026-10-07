import SwiftUI

enum Theme {
    /// Deep ink blue, the main accent.
    static let ink = Color(red: 0.13, green: 0.27, blue: 0.56)
    /// Teacher's red pen, for corrections.
    static let pen = Color(red: 0.80, green: 0.18, blue: 0.20)
    /// Green tick.
    static let good = Color(red: 0.16, green: 0.55, blue: 0.33)
    static let warn = Color(red: 0.85, green: 0.55, blue: 0.10)

    static func levelColor(_ level: String) -> Color {
        switch level {
        case "C2": return Color(red: 0.45, green: 0.22, blue: 0.62)
        case "C1": return ink
        default: return Color(red: 0.30, green: 0.50, blue: 0.55)
        }
    }

    static func scoreColor(_ score: Int) -> Color {
        switch score {
        case 600...: return Color(red: 0.45, green: 0.22, blue: 0.62)
        case 500..<600: return good
        case 400..<500: return warn
        default: return pen
        }
    }
}

struct LevelBadge: View {
    let level: String
    var body: some View {
        Text(level)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundColor(.white)
            .background(Theme.levelColor(level), in: Capsule())
    }
}

struct SectionCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ScoreBar: View {
    let label: String
    let score: Int?
    let target: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                if let s = score {
                    Text("\(s)").font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundColor(Theme.scoreColor(s))
                    Text(Level.cefr(s)).font(.caption.weight(.bold)).foregroundColor(.secondary)
                } else {
                    Text("à mesurer").font(.caption).foregroundColor(.secondary)
                }
            }
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule().fill(Theme.scoreColor(score ?? 0))
                        .frame(width: w * CGFloat(min(699, score ?? 0)) / 699.0)
                    // C1 and C2 thresholds
                    Rectangle().fill(Color.primary.opacity(0.35)).frame(width: 1)
                        .offset(x: w * 500.0 / 699.0)
                    Rectangle().fill(Color.primary.opacity(0.35)).frame(width: 1)
                        .offset(x: w * 600.0 / 699.0)
                    Circle().stroke(Theme.ink, lineWidth: 2).frame(width: 8, height: 8)
                        .offset(x: w * CGFloat(target) / 699.0 - 4)
                }
            }
            .frame(height: 8)
        }
    }
}
