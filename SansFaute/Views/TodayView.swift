import SwiftUI

/// Starting point from the October TCF attestation, and the targets for 9 November.
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

struct TodayView: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        NavigationStack {
            List {
                Section { countdown }
                todaySection
                Section("Objectif TCF") {
                    ForEach(Baseline.scores) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            ScoreBar(label: row.skill.title, score: progress.recentEstimate(row.skill), target: row.target)
                            Text("Départ \(row.start) · objectif \(row.target)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    Text("Les barres montrent ton estimation sur tes 5 derniers tests. Repères verticaux : C1 à 500, C2 à 600. Le cercle marque ton objectif.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Section {
                    NavigationLink {
                        PlanView()
                    } label: {
                        Label("Programme complet jusqu'au 9 novembre", systemImage: "calendar")
                    }
                    NavigationLink {
                        ResourcesView()
                    } label: {
                        Label("Ce qui fait un C2, et où s'entraîner", systemImage: "books.vertical")
                    }
                    NavigationLink {
                        QuizView(title: "Mes erreurs", kind: "Entraînement", examMode: false,
                                 items: content.mistakeReview(progress.state.mistakes))
                    } label: {
                        HStack {
                            Label("Revoir mes erreurs", systemImage: "pencil.and.outline")
                            Spacer()
                            if !progress.state.mistakes.isEmpty {
                                Text("\(progress.state.mistakes.count)")
                                    .font(.caption.weight(.bold)).foregroundColor(.white)
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Theme.pen, in: Capsule())
                            }
                        }
                    }
                }
            }
            .navigationTitle("SansFaute")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    private var countdown: some View {
        let days = progress.daysUntilExam
        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(days > 0 ? "J-\(days)" : (days == 0 ? "Jour J" : "Terminé"))
                    .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundColor(Theme.ink)
                Text("TCF TP · \(progress.state.examDate.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "fr_FR"))))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(progress.streak)")
                    .font(.title.weight(.bold).monospacedDigit())
                    .foregroundColor(progress.streak > 0 ? Theme.warn : .secondary)
                Text(progress.streak > 1 ? "jours d'affilée" : "jour d'affilée")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var todaySection: some View {
        if let day = content.planDay(for: Date()) {
            let minutes = day.tasks.reduce(0) { $0 + $1.minutes }
            Section {
                ForEach(Array(day.tasks.enumerated()), id: \.offset) { pair in
                    TaskRow(day: day, index: pair.offset, task: pair.element)
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jour \(day.day) · \(minutes) min")
                    Text(day.phase).textCase(nil).font(.caption).foregroundColor(.secondary)
                }
            }
        } else {
            Section("Aujourd'hui") {
                NavigationLink {
                    QuizView(title: "Test du jour", kind: "Test du jour", examMode: false,
                             items: content.dailyTest(date: Date(), mistakes: progress.state.mistakes), saveResult: true)
                } label: {
                    Label("Test du jour", systemImage: "bolt")
                }
                NavigationLink {
                    VocabSessionView()
                } label: {
                    Label("Cartes de vocabulaire", systemImage: "rectangle.stack")
                }
            }
        }
    }
}

struct TaskRow: View {
    let day: PlanDay
    let index: Int
    let task: PlanTask

    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    private var done: Bool { progress.isDone(day: day.date, index: index) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                progress.toggle(day: day.date, index: index)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(done ? Theme.good : .secondary)
            }
            .buttonStyle(.borderless)

            if hasDestination {
                NavigationLink {
                    destination
                } label: {
                    rowLabel
                }
            } else {
                rowLabel
            }
        }
    }

    private var rowLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(task.label)
                .strikethrough(done, color: .secondary)
                .foregroundColor(done ? .secondary : .primary)
            if let detail = detail {
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private var detail: String? {
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

    private var hasDestination: Bool {
        ["listening", "lesson", "reading", "vocab", "daily", "mock", "test", "review", "external"].contains(task.kind)
    }

    @ViewBuilder
    private var destination: some View {
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
