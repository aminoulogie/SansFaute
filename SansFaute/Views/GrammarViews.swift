import SwiftUI

struct GrammarHomeView: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Structures : 518 → 580")
                            .font(.headline)
                        Text("Le TCF teste surtout le mode après les conjonctions, la concordance des temps, les relatifs composés, les accords et le choix du mot exact. Chaque leçon finit par des exercices corrigés.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    NavigationLink {
                        QuizView(title: "Mélange C1 · C2", kind: "Entraînement", examMode: false,
                                 items: Array(content.grammar.filter { $0.level != "B2" }.shuffled().prefix(20)).map { QuizItem(question: $0) })
                    } label: {
                        Label("20 questions mélangées", systemImage: "shuffle")
                    }
                }
                Section("Leçons") {
                    ForEach(content.lessons) { lesson in
                        NavigationLink {
                            LessonView(lesson: lesson)
                        } label: {
                            LessonRow(lesson: lesson)
                        }
                    }
                }
            }
            .navigationTitle("Grammaire")
        }
    }
}

struct LessonRow: View {
    let lesson: Lesson
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        let stat = progress.accuracy(topic: lesson.id)
        let count = content.questions(topic: lesson.id).count
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                Text(stat.total > 0
                     ? "\(Int((stat.ratio * 100).rounded())) % de réussite sur \(stat.total) réponses"
                     : "\(count) exercices")
                    .font(.caption)
                    .foregroundColor(stat.total == 0 ? .secondary : (stat.ratio >= 0.8 ? Theme.good : (stat.ratio >= 0.6 ? Theme.warn : Theme.pen)))
            }
            Spacer()
            LevelBadge(level: lesson.level)
        }
    }
}

struct LessonView: View {
    let lesson: Lesson
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var speaker: Speaker
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        let questions = content.questions(topic: lesson.id)
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    LevelBadge(level: lesson.level)
                    Text(lesson.title).font(.title2.weight(.bold))
                    Text(lesson.summary).foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            ForEach(lesson.rules, id: \.title) { rule in
                Section(rule.title) {
                    Text(rule.explanation)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(rule.examples, id: \.self) { ex in
                        Button {
                            speaker.say(ex, rate: progress.state.speechRate)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "speaker.wave.2").font(.caption).foregroundColor(Theme.ink).padding(.top, 3)
                                Text(ex).italic().foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section {
                Label {
                    Text(lesson.trap).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.pen)
                }
            } header: {
                Text("Le piège du test")
            }
            if !questions.isEmpty {
                Section {
                    NavigationLink {
                        QuizView(title: lesson.title, kind: "Entraînement", examMode: false, items: content.practice(topic: lesson.id))
                    } label: {
                        Label("S'entraîner · \(questions.count) questions", systemImage: "pencil")
                            .font(.headline)
                    }
                }
            }
        }
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { speaker.stop() }
    }
}
