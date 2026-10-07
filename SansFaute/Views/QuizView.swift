import SwiftUI

/// Runs any list of questions, in practice mode (instant correction)
/// or exam mode (one listening, no correction until the end).
struct QuizView: View {
    let title: String
    let kind: String
    let examMode: Bool
    let saveResult: Bool
    /// Snapshot taken once, so the questions never change mid-quiz when the parent redraws.
    @State private var items: [QuizItem]

    init(title: String, kind: String, examMode: Bool, items: [QuizItem], saveResult: Bool = false) {
        self.title = title
        self.kind = kind
        self.examMode = examMode
        self.saveResult = saveResult
        _items = State(initialValue: items)
    }

    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var speaker: Speaker

    @State private var index = 0
    @State private var selected: Int? = nil
    @State private var revealed = false
    @State private var answers: [String: Int] = [:]
    @State private var playedGroups: Set<String> = []
    @State private var startDate = Date()
    @State private var result: TestResult? = nil
    @State private var showTranscript = false

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else if let r = result {
                QuizSummaryView(result: r, items: items, answers: answers)
            } else {
                questionScreen
            }
        }
        .paperBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { speaker.stop() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundColor(Theme.good)
            Text("Rien à revoir").font(.serif(.title2, weight: .bold))
            Text("Les questions ratées apparaîtront ici automatiquement, jusqu'à ce que tu les réussisses.")
                .font(.subheadline).foregroundColor(Theme.muted)
        }
        .multilineTextAlignment(.center)
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var current: QuizItem { items[min(index, items.count - 1)] }

    private var questionScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let segments = current.segments {
                    AudioPanel(segments: segments, groupId: current.groupId, examMode: examMode, played: $playedGroups)
                }
                if let passage = current.passage {
                    PassagePanel(title: current.passageTitle, text: passage)
                }
                Text(current.question.prompt)
                    .font(.serif(.title3))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                VStack(spacing: 10) {
                    ForEach(Array(current.question.options.enumerated()), id: \.offset) { pair in
                        optionButton(index: pair.offset, text: pair.element)
                    }
                }
                if revealed && !examMode {
                    feedback
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                nextButton
            }
            .padding(20)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(items.indices, id: \.self) { i in
                    Capsule()
                        .fill(segmentColor(i))
                        .frame(height: 5)
                }
            }
            .frame(height: 5)
            HStack(spacing: 8) {
                Text("\(index + 1) / \(items.count)")
                    .font(.number(13, weight: .semibold))
                    .foregroundColor(Theme.muted)
                Label(Skill.of(current.question).shortTitle, systemImage: Skill.of(current.question).symbol)
                    .font(.caption)
                    .foregroundColor(Theme.muted)
                Spacer()
                if examMode {
                    TimelineView(.periodic(from: startDate, by: 1)) { context in
                        let s = Int(context.date.timeIntervalSince(startDate))
                        Label(String(format: "%d:%02d", s / 60, s % 60), systemImage: "timer")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(Theme.muted)
                    }
                }
                LevelBadge(level: current.question.level)
            }
        }
    }

    private func segmentColor(_ i: Int) -> Color {
        if i == index { return Theme.ink }
        if i > index { return Theme.inkSoft }
        if examMode { return Theme.ink.opacity(0.45) }
        let item = items[i]
        guard let a = answers[item.id] else { return Theme.inkSoft }
        return a == item.question.answer ? Theme.good : Theme.pen
    }

    private func optionButton(index i: Int, text: String) -> some View {
        let isSelected = selected == i
        let isAnswer = current.question.answer == i
        let letter = ["A", "B", "C", "D", "E", "F"][min(i, 5)]
        var fill = Theme.card
        var stroke = Theme.stroke
        var badgeFill = Theme.inkSoft
        var badgeText = Theme.ink
        var symbol: String? = nil
        if revealed && !examMode {
            if isAnswer {
                fill = Theme.goodSoft; stroke = Theme.good; badgeFill = Theme.good; badgeText = .white; symbol = "checkmark"
            } else if isSelected {
                fill = Theme.penSoft; stroke = Theme.pen; badgeFill = Theme.pen; badgeText = .white; symbol = "xmark"
            }
        } else if isSelected {
            fill = Theme.inkSoft; stroke = Theme.ink; badgeFill = Theme.ink; badgeText = .white
        }
        return Button {
            choose(i)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle().fill(badgeFill).frame(width: 30, height: 30)
                    if let s = symbol {
                        Image(systemName: s).font(.caption.weight(.heavy)).foregroundColor(badgeText)
                    } else {
                        Text(letter).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(badgeText)
                    }
                }
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(stroke, lineWidth: isSelected || (revealed && isAnswer) ? 1.8 : 0.8))
        }
        .buttonStyle(PressableStyle())
        .disabled(revealed && !examMode)
    }

    private var feedback: some View {
        let correct = selected == current.question.answer
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.seal.fill" : "pencil.and.outline")
                Text(correct ? "Juste" : "Faux").font(.serif(.headline, weight: .bold))
            }
            .foregroundColor(correct ? Theme.good : Theme.pen)
            Text(current.question.explanation)
                .fixedSize(horizontal: false, vertical: true)
            if let segments = current.segments {
                DisclosureGroup("Transcription", isExpanded: $showTranscript) {
                    Text(ListeningItem(id: "", title: "", level: "", kind: "", segments: segments, questions: []).transcript)
                        .font(.system(.callout, design: .serif))
                        .foregroundColor(Theme.muted)
                        .padding(.top, 6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .tint(Theme.ink)
            }
        }
        .card(fill: correct ? Theme.goodSoft : Theme.penSoft)
    }

    private var nextButton: some View {
        let last = index + 1 >= items.count
        return Button {
            next()
        } label: {
            Label(last ? "Voir le résultat" : "Suivant", systemImage: last ? "flag.checkered" : "arrow.right")
        }
        .buttonStyle(InkButtonStyle())
        .opacity((examMode ? selected == nil : !revealed) ? 0.4 : 1)
        .disabled(examMode ? selected == nil : !revealed)
        .padding(.top, 4)
    }

    // MARK: - Flow

    private func choose(_ i: Int) {
        if examMode {
            Haptics.tap()
            selected = i
        } else if !revealed {
            selected = i
            let ok = i == current.question.answer
            ok ? Haptics.success() : Haptics.error()
            withAnimation(.easeOut(duration: 0.25)) { revealed = true }
            answers[current.id] = i
            progress.record(current.question, correct: ok)
        }
    }

    private func next() {
        if examMode, let s = selected {
            answers[current.id] = s
            progress.record(current.question, correct: s == current.question.answer)
        }
        if index + 1 < items.count {
            let previousGroup = current.groupId
            index += 1
            selected = nil
            revealed = false
            showTranscript = false
            if current.groupId != previousGroup || current.groupId == nil { speaker.stop() }
        } else {
            finish()
        }
    }

    private func finish() {
        speaker.stop()
        var bySkill: [String: SkillScore] = [:]
        var graded: [(level: String, correct: Bool)] = []
        var correct = 0
        for item in items {
            let ok = answers[item.id] == item.question.answer
            if ok { correct += 1 }
            let skill = Skill.of(item.question).rawValue
            var s = bySkill[skill, default: SkillScore()]
            s.total += 1
            if ok { s.correct += 1 }
            bySkill[skill] = s
            graded.append((level: item.question.level, correct: ok))
        }
        let r = TestResult(date: Date(), kind: kind, correct: correct, total: items.count,
                           estimate: Level.estimate(graded), bySkill: bySkill)
        if saveResult { progress.save(result: r) }
        progress.addStudy(seconds: Int(Date().timeIntervalSince(startDate)))
        correct == items.count ? Haptics.success() : Haptics.tap()
        withAnimation { result = r }
    }
}

// MARK: - Pieces

struct AudioPanel: View {
    let segments: [Segment]
    let groupId: String?
    let examMode: Bool
    @Binding var played: Set<String>

    @EnvironmentObject private var speaker: Speaker
    @EnvironmentObject private var progress: ProgressStore

    private var alreadyPlayed: Bool { groupId.map { played.contains($0) } ?? false }
    private var locked: Bool { examMode && alreadyPlayed && !speaker.isSpeaking }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                if speaker.isSpeaking {
                    speaker.stop()
                } else {
                    if let g = groupId { played.insert(g) }
                    speaker.speak(segments, rate: progress.state.speechRate)
                }
            } label: {
                ZStack {
                    Circle().fill(locked ? Theme.muted.opacity(0.3) : Theme.ink).frame(width: 56, height: 56)
                    Image(systemName: speaker.isSpeaking ? "stop.fill" : (locked ? "lock.fill" : "play.fill"))
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PressableStyle())
            .disabled(locked)

            VStack(alignment: .leading, spacing: 4) {
                Text(speaker.isSpeaking ? "Écoute en cours…" : (locked ? "Document déjà écouté" : "Document audio"))
                    .font(.subheadline.weight(.semibold))
                Text(examMode ? "Une seule écoute, comme au TCF. Lis les réponses d'abord." : "Réécoute autant que tu veux.")
                    .font(.caption).foregroundColor(Theme.muted)
                if speaker.isSpeaking {
                    WaveBars().frame(height: 14)
                }
            }
            Spacer(minLength: 0)
        }
        .card(padding: 14, fill: Theme.cardRaised)
    }
}

struct WaveBars: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<14, id: \.self) { i in
                    Capsule()
                        .fill(Theme.ink.opacity(0.7))
                        .frame(width: 3, height: 4 + 10 * abs(sin(t * 5 + Double(i) * 0.6)))
                }
            }
        }
    }
}

struct PassagePanel: View {
    let title: String?
    let text: String
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "doc.text").foregroundColor(Theme.ink)
                    Text(title ?? "Document").font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").foregroundColor(Theme.muted)
                }
            }
            .buttonStyle(.plain)
            if expanded {
                Text(text)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .card(fill: Theme.cardRaised)
    }
}

struct QuizSummaryView: View {
    let result: TestResult
    let items: [QuizItem]
    let answers: [String: Int]
    @Environment(\.dismiss) private var dismiss

    private var wrong: [QuizItem] { items.filter { answers[$0.id] != $0.question.answer } }
    private var ratio: Double { result.total == 0 ? 0 : Double(result.correct) / Double(result.total) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 10) {
                    ZStack {
                        ProgressRing(progress: ratio, lineWidth: 12, color: Theme.ratioColor(ratio))
                        VStack(spacing: 0) {
                            Text("\(result.correct)").font(.number(44))
                            Text("sur \(result.total)").font(.caption).foregroundColor(Theme.muted)
                        }
                    }
                    .frame(width: 150, height: 150)
                    HStack(spacing: 8) {
                        Text("Score estimé").foregroundColor(Theme.muted)
                        Text("\(result.estimate)").font(.number(20)).foregroundColor(Theme.scoreColor(result.estimate))
                        LevelBadge(level: Level.cefr(result.estimate))
                    }
                    Text("Estimation indicative sur 699, pondérée par le niveau des questions.")
                        .font(.caption2).foregroundColor(Theme.muted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .card(padding: 20)

                VStack(spacing: 12) {
                    ForEach(Skill.allCases, id: \.self) { skill in
                        if let s = result.bySkill[skill.rawValue], s.total > 0 {
                            HStack {
                                Label(skill.title, systemImage: skill.symbol).font(.subheadline)
                                Spacer()
                                Text("\(s.correct)/\(s.total)").font(.number(15)).foregroundColor(Theme.ratioColor(s.ratio))
                            }
                        }
                    }
                }
                .card()

                if wrong.isEmpty {
                    Label("Sans faute. Bravo.", systemImage: "star.fill")
                        .font(.serif(.title3, weight: .bold))
                        .foregroundColor(Theme.good)
                        .card(fill: Theme.goodSoft)
                } else {
                    SectionHeader(eyebrow: "\(wrong.count) à retenir", title: "La correction")
                    ForEach(wrong) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.question.prompt).font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            if let a = answers[item.id], a < item.question.options.count {
                                Label(item.question.options[a], systemImage: "xmark").font(.subheadline).foregroundColor(Theme.pen)
                            } else {
                                Label("Sans réponse", systemImage: "minus").font(.subheadline).foregroundColor(Theme.pen)
                            }
                            Label(item.question.options[item.question.answer], systemImage: "checkmark")
                                .font(.subheadline.weight(.semibold)).foregroundColor(Theme.good)
                            Text(item.question.explanation).font(.caption).foregroundColor(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .card(padding: 14)
                    }
                }

                Button("Terminer") { dismiss() }
                    .buttonStyle(InkButtonStyle())
            }
            .padding(20)
        }
        .overlay { if wrong.isEmpty { Confetti() } }
    }
}
