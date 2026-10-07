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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { speaker.stop() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle").font(.system(size: 44)).foregroundColor(Theme.good)
            Text("Rien à revoir ici pour l'instant.").font(.headline)
            Text("Les questions ratées apparaîtront ici automatiquement.").font(.subheadline).foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding()
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
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    ForEach(Array(current.question.options.enumerated()), id: \.offset) { pair in
                        optionButton(index: pair.offset, text: pair.element)
                    }
                }
                if revealed && !examMode {
                    feedback
                }
                nextButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(index), total: Double(items.count))
            HStack {
                Text("Question \(index + 1) / \(items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                Image(systemName: Skill.of(current.question).symbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if examMode {
                    TimelineView(.periodic(from: startDate, by: 1)) { context in
                        let s = Int(context.date.timeIntervalSince(startDate))
                        Text(String(format: "%d:%02d", s / 60, s % 60))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                LevelBadge(level: current.question.level)
            }
        }
    }

    private func optionButton(index i: Int, text: String) -> some View {
        let isSelected = selected == i
        let isAnswer = current.question.answer == i
        var fill = Color(.secondarySystemGroupedBackground)
        var stroke = Color.clear
        var symbol = "circle"
        if revealed && !examMode {
            if isAnswer { fill = Theme.good.opacity(0.15); stroke = Theme.good; symbol = "checkmark.circle.fill" }
            else if isSelected { fill = Theme.pen.opacity(0.12); stroke = Theme.pen; symbol = "xmark.circle.fill" }
        } else if isSelected {
            fill = Theme.ink.opacity(0.12); stroke = Theme.ink; symbol = "largecircle.fill.circle"
        }
        return Button {
            choose(i)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .foregroundColor(stroke == .clear ? .secondary : stroke)
                Text(text)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(stroke, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(revealed && !examMode)
    }

    private var feedback: some View {
        let correct = selected == current.question.answer
        return VStack(alignment: .leading, spacing: 8) {
            Label(correct ? "Juste" : "Faux", systemImage: correct ? "checkmark.seal.fill" : "pencil.and.outline")
                .font(.headline)
                .foregroundColor(correct ? Theme.good : Theme.pen)
            Text(current.question.explanation)
                .fixedSize(horizontal: false, vertical: true)
            if let segments = current.segments {
                DisclosureGroup("Transcription", isExpanded: $showTranscript) {
                    Text(ListeningItem(id: "", title: "", level: "", kind: "", segments: segments, questions: []).transcript)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var nextButton: some View {
        let last = index + 1 >= items.count
        return Button {
            next()
        } label: {
            Text(last ? "Voir le résultat" : "Suivant")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(examMode ? selected == nil : !revealed)
        .padding(.top, 4)
    }

    // MARK: - Flow

    private func choose(_ i: Int) {
        if examMode {
            selected = i
        } else if !revealed {
            selected = i
            revealed = true
            answers[current.id] = i
            progress.record(current.question, correct: i == current.question.answer)
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
        result = r
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
        HStack(spacing: 12) {
            Image(systemName: speaker.isSpeaking ? "waveform" : "ear")
                .font(.title2)
                .foregroundColor(Theme.ink)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(examMode ? "Une seule écoute" : "Document audio").font(.subheadline.weight(.semibold))
                Text(examMode ? "Comme au TCF. Lis les réponses avant de lancer." : "Réécoute autant que nécessaire.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button {
                if speaker.isSpeaking {
                    speaker.stop()
                } else {
                    if let g = groupId { played.insert(g) }
                    speaker.speak(segments, rate: progress.state.speechRate)
                }
            } label: {
                Image(systemName: speaker.isSpeaking ? "stop.fill" : (locked ? "lock.fill" : "play.fill"))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderedProminent)
            .disabled(locked)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct PassagePanel: View {
    let title: String?
    let text: String
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "doc.text").foregroundColor(Theme.ink)
                    Text(title ?? "Document").font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            if expanded {
                Text(text)
                    .font(.body)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct QuizSummaryView: View {
    let result: TestResult
    let items: [QuizItem]
    let answers: [String: Int]
    @Environment(\.dismiss) private var dismiss

    private var wrong: [QuizItem] { items.filter { answers[$0.id] != $0.question.answer } }

    var body: some View {
        List {
            Section {
                VStack(spacing: 6) {
                    Text("\(result.correct) / \(result.total)")
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    HStack(spacing: 6) {
                        Text("Score estimé").foregroundColor(.secondary)
                        Text("\(result.estimate)").fontWeight(.semibold).foregroundColor(Theme.scoreColor(result.estimate))
                        LevelBadge(level: Level.cefr(result.estimate))
                    }
                    .font(.subheadline)
                    Text("Estimation indicative sur 699, pondérée par le niveau des questions.")
                        .font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Section("Par compétence") {
                ForEach(Skill.allCases, id: \.self) { skill in
                    if let s = result.bySkill[skill.rawValue], s.total > 0 {
                        HStack {
                            Label(skill.title, systemImage: skill.symbol)
                            Spacer()
                            Text("\(s.correct)/\(s.total)").monospacedDigit()
                                .foregroundColor(s.ratio >= 0.8 ? Theme.good : (s.ratio >= 0.6 ? Theme.warn : Theme.pen))
                        }
                    }
                }
            }
            if !wrong.isEmpty {
                Section("À retenir (\(wrong.count))") {
                    ForEach(wrong) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.question.prompt).font(.subheadline.weight(.semibold))
                            if let a = answers[item.id], a < item.question.options.count {
                                Text("Ta réponse : \(item.question.options[a])").font(.caption).foregroundColor(Theme.pen)
                            } else {
                                Text("Sans réponse").font(.caption).foregroundColor(Theme.pen)
                            }
                            Text("Bonne réponse : \(item.question.options[item.question.answer])")
                                .font(.caption).foregroundColor(Theme.good)
                            Text(item.question.explanation).font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                Section {
                    Label("Sans faute. Bravo.", systemImage: "star.fill").foregroundColor(Theme.good)
                }
            }
            Section {
                Button("Terminer") { dismiss() }
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
