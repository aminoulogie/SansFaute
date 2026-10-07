import SwiftUI

/// Starting point from the TCF attestation, and the targets for 9 November.
struct BaselineRow: Identifiable {
    let skill: Skill
    let start: Int
    let target: Int
    var id: String { skill.rawValue }
}

enum Baseline {
    static let scores: [BaselineRow] = [
        BaselineRow(skill: .listening, start: 487, target: 530),
        BaselineRow(skill: .structures, start: 518, target: 580),
        BaselineRow(skill: .reading, start: 555, target: 610)
    ]
    static let global = 520
}

enum FR {
    static let locale = Locale(identifier: "fr_FR")
    static func longDate(_ d: Date) -> String {
        let s = d.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
        return s.prefix(1).uppercased() + String(s.dropFirst())
    }
    static func shortDate(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.wide).locale(locale))
    }
}

struct TodayView: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    if let day = content.planDay(for: Date()) {
                        NavigationLink {
                            GuidedSessionView(day: day)
                        } label: {
                            Label("Commencer ma séance guidée", systemImage: "play.fill")
                        }
                        .buttonStyle(InkButtonStyle())

                        SectionHeader(eyebrow: "Jour \(day.day) · \(day.phase)", title: "Au programme aujourd'hui")
                        VStack(spacing: 10) {
                            ForEach(Array(day.tasks.enumerated()), id: \.offset) { pair in
                                TaskCard(day: day, index: pair.offset, task: pair.element)
                            }
                        }
                    } else {
                        offPlan
                    }

                    SectionHeader(eyebrow: "Entraînement express", title: "5 minutes devant toi ?")
                    LazyVGrid(columns: columns, spacing: 12) {
                        NavigationLink { DictationHomeView() } label: {
                            Tile(symbol: "pencil.line", title: "Dictée", subtitle: "Écoute, écris, la correction souligne chaque faute", color: Theme.pen)
                        }
                        NavigationLink { SprintView() } label: {
                            Tile(symbol: "stopwatch", title: "Sprint 60 s", subtitle: "Record : \(progress.state.sprintBest) bonnes réponses", color: Theme.warn)
                        }
                        NavigationLink { ShadowingPickerView() } label: {
                            Tile(symbol: "waveform", title: "Phrase par phrase", subtitle: "Réécoute et répète chaque phrase", color: Theme.ink)
                        }
                        NavigationLink { TrapsView() } label: {
                            Tile(symbol: "exclamationmark.triangle", title: "Pièges flash", subtitle: "Les 15 pièges du TCF en cartes", color: Theme.violet)
                        }
                    }
                    .buttonStyle(PressableStyle())

                    SectionHeader(eyebrow: "Objectif 9 novembre", title: "Où tu en es")
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Baseline.scores) { row in
                            ScoreBar(label: row.skill.title, score: progress.recentEstimate(row.skill), start: row.start, target: row.target)
                        }
                        Text("Estimation sur tes 5 derniers tests. Avant ton premier test, la barre pâle montre ton score d'octobre.")
                            .font(.caption2)
                            .foregroundColor(Theme.muted)
                    }
                    .card()

                    VStack(spacing: 10) {
                        NavigationLink {
                            QuizView(title: "Mes erreurs", kind: "Entraînement", examMode: false,
                                     items: content.mistakeReview(progress.state.mistakes))
                        } label: {
                            RowCard(symbol: "pencil.and.outline", title: "Revoir mes erreurs",
                                    subtitle: "Chaque question ratée revient jusqu'à ce que tu la réussisses",
                                    color: Theme.pen,
                                    trailing: progress.state.mistakes.isEmpty ? nil : "\(progress.state.mistakes.count)")
                        }
                        NavigationLink { PlanView() } label: {
                            RowCard(symbol: "calendar", title: "Programme complet", subtitle: "33 jours jusqu'au TCF")
                        }
                        NavigationLink { ResourcesView() } label: {
                            RowCard(symbol: "books.vertical", title: "C2, stratégies et jour J", subtitle: "Ce que demande le C2, liens, check-list", color: Theme.violet)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SansFaute").font(.serif(.headline, weight: .bold)).foregroundColor(Theme.ink)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                }
            }
        }
    }

    private var hero: some View {
        let days = progress.daysUntilExam
        let ratio = content.planDay(for: Date()).map { progress.doneRatio(for: $0) } ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: FR.longDate(Date()))
                    Text(days > 0 ? "J-\(days)" : (days == 0 ? "Jour J" : "Terminé"))
                        .font(.system(size: 64, weight: .black, design: .serif))
                        .foregroundColor(Theme.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("TCF Tout public · \(FR.shortDate(progress.state.examDate))")
                        .font(.subheadline)
                        .foregroundColor(Theme.muted)
                }
                Spacer()
                ZStack {
                    ProgressRing(progress: ratio, lineWidth: 9, color: ratio >= 1 ? Theme.good : Theme.ink)
                    VStack(spacing: 0) {
                        Text("\(Int((ratio * 100).rounded()))%").font(.number(19))
                        Text("du jour").font(.caption2).foregroundColor(Theme.muted)
                    }
                }
                .frame(width: 84, height: 84)
            }
            HStack(spacing: 8) {
                Chip(symbol: "flame.fill", text: progress.streak > 1 ? "\(progress.streak) jours d'affilée" : "\(progress.streak) jour", color: Theme.warn)
                Chip(symbol: "clock.fill", text: "\(progress.minutes(on: Date())) min aujourd'hui", color: Theme.ink)
                if let est = progress.latestEstimate {
                    Chip(symbol: "chart.line.uptrend.xyaxis", text: "\(est)", color: Theme.scoreColor(est))
                }
            }
        }
        .card(padding: 18)
        .padding(.top, 6)
    }

    private var offPlan: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(progress.daysUntilExam < 0 ? "L'examen est passé. Bravo pour le travail !" : "Pas de séance prévue aujourd'hui.")
                .font(.serif(.title3))
            Text("Tu peux quand même faire le test du jour, une dictée ou tes cartes.")
                .font(.subheadline).foregroundColor(Theme.muted)
            NavigationLink {
                QuizView(title: "Test du jour", kind: "Test du jour", examMode: false,
                         items: content.dailyTest(date: Date(), mistakes: progress.state.mistakes), saveResult: true)
            } label: {
                Label("Test du jour", systemImage: "bolt.fill")
            }
            .buttonStyle(InkButtonStyle())
        }
        .card()
    }
}

struct Chip: View {
    let symbol: String
    let text: String
    var color: Color = Theme.ink
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption2)
            Text(text).font(.caption.weight(.semibold)).lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Tasks

struct TaskCard: View {
    let day: PlanDay
    let index: Int
    let task: PlanTask

    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    private var done: Bool { progress.isDone(day: day.date, index: index) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap()
                withAnimation(.spring(response: 0.3)) { progress.toggle(day: day.date, index: index) }
            } label: {
                ZStack {
                    Circle().stroke(done ? Theme.good : Theme.muted.opacity(0.5), lineWidth: 2).frame(width: 26, height: 26)
                    if done {
                        Circle().fill(Theme.good).frame(width: 26, height: 26)
                        Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            if TaskDestination.exists(for: task) {
                NavigationLink {
                    TaskDestination(task: task)
                } label: {
                    labelBlock
                }
                .buttonStyle(PressableStyle())
            } else {
                labelBlock
            }
        }
        .card(padding: 14, fill: done ? Theme.goodSoft : Theme.card)
    }

    private var labelBlock: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(task.label)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(done, color: Theme.muted)
                    .foregroundColor(done ? Theme.muted : .primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = TaskDestination.detail(for: task, content: content) {
                    Text(detail).font(.caption).foregroundColor(Theme.muted)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: TaskDestination.symbol(for: task))
                .foregroundColor(Theme.ink.opacity(0.7))
        }
        .contentShape(Rectangle())
    }
}

/// Where each kind of plan task leads.
struct TaskDestination: View {
    let task: PlanTask
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    static func exists(for task: PlanTask) -> Bool {
        ["listening", "lesson", "reading", "vocab", "daily", "mock", "test", "review", "external"].contains(task.kind)
    }

    static func symbol(for task: PlanTask) -> String {
        switch task.kind {
        case "listening": return "headphones"
        case "lesson": return "textformat"
        case "reading": return "doc.text"
        case "vocab": return "rectangle.stack"
        case "daily": return "bolt.fill"
        case "mock", "test": return "timer"
        case "review": return "pencil.and.outline"
        case "external": return "radio"
        case "rest": return "moon.zzz"
        default: return "chevron.right"
        }
    }

    static func detail(for task: PlanTask, content: ContentStore) -> String? {
        var parts: [String] = []
        if task.minutes > 0 { parts.append("\(task.minutes) min") }
        switch task.kind {
        case "listening": if let l = content.listeningItem(task.ref) { parts.append(l.title) }
        case "lesson": if let l = content.lesson(task.ref) { parts.append(l.title) }
        case "reading": if let r = content.readingItem(task.ref) { parts.append(r.title) }
        default: break
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        switch task.kind {
        case "listening":
            if let item = content.listeningItem(task.ref) {
                ListeningDetailView(item: item, examDefault: task.label.contains("examen"))
            }
        case "lesson":
            if let lesson = content.lesson(task.ref) { LessonView(lesson: lesson) }
        case "reading":
            if let item = content.readingItem(task.ref) {
                QuizView(title: item.title, kind: "Entraînement", examMode: false, items: content.items(for: item))
            }
        case "vocab":
            VocabSessionView()
        case "daily":
            QuizView(title: "Test du jour", kind: "Test du jour", examMode: false,
                     items: content.dailyTest(date: Date(), mistakes: progress.state.mistakes), saveResult: true)
        case "mock", "test":
            QuizView(title: "Test blanc", kind: "Test blanc", examMode: true, items: content.mockTest(), saveResult: true)
        case "review":
            QuizView(title: "Mes erreurs", kind: "Entraînement", examMode: false,
                     items: content.mistakeReview(progress.state.mistakes))
        case "external":
            ResourcesView()
        default:
            EmptyView()
        }
    }
}
