import SwiftUI

struct GrammarHomeView: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var overall: SkillScore {
        var s = SkillScore()
        for l in content.lessons {
            let a = progress.accuracy(topic: l.id)
            s.correct += a.correct
            s.total += a.total
        }
        return s
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Eyebrow(text: "Structures de la langue")
                                Text("518 → 580").font(.system(size: 38, weight: .black, design: .serif)).foregroundColor(Theme.ink)
                                Text("\(content.grammar.count) exercices · \(content.lessons.count) leçons").font(.subheadline).foregroundColor(Theme.muted)
                            }
                            Spacer()
                            ZStack {
                                ProgressRing(progress: overall.ratio, lineWidth: 8, color: Theme.ratioColor(overall.ratio))
                                Text(overall.total == 0 ? "–" : "\(Int((overall.ratio * 100).rounded()))%").font(.number(16))
                            }
                            .frame(width: 64, height: 64)
                        }
                        Text("Le TCF vérifie surtout le mode après les conjonctions, la concordance des temps, les relatifs composés, les accords et le mot exact.")
                            .font(.footnote).foregroundColor(Theme.muted)
                    }
                    .card(padding: 18)
                    .padding(.top, 6)

                    LazyVGrid(columns: columns, spacing: 12) {
                        NavigationLink { SprintView() } label: {
                            Tile(symbol: "stopwatch", title: "Sprint 60 s", subtitle: "Record : \(progress.state.sprintBest)", color: Theme.warn)
                        }
                        NavigationLink { TrapsView() } label: {
                            Tile(symbol: "exclamationmark.triangle", title: "Pièges flash", subtitle: "Une carte par piège", color: Theme.violet)
                        }
                        NavigationLink {
                            QuizView(title: "Mélange C1 · C2", kind: "Entraînement", examMode: false,
                                     items: Array(content.grammar.filter { $0.level != "B2" }.shuffled().prefix(20)).map { QuizItem(question: $0) })
                        } label: {
                            Tile(symbol: "shuffle", title: "20 au hasard", subtitle: "Toutes les leçons mélangées", color: Theme.ink)
                        }
                        NavigationLink {
                            QuizView(title: "Points faibles", kind: "Entraînement", examMode: false, items: weakItems)
                        } label: {
                            Tile(symbol: "scope", title: "Points faibles", subtitle: "Tes leçons les moins réussies", color: Theme.pen)
                        }
                    }
                    .buttonStyle(PressableStyle())

                    SectionHeader(eyebrow: "15 leçons", title: "Les pièges du TCF")
                    VStack(spacing: 10) {
                        ForEach(content.lessons) { lesson in
                            NavigationLink {
                                LessonView(lesson: lesson)
                            } label: {
                                LessonRow(lesson: lesson)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .paperBackground()
            .navigationTitle("Grammaire")
        }
    }

    /// Questions from the three weakest lessons (or untouched ones first).
    private var weakItems: [QuizItem] {
        let ranked = content.lessons.sorted { a, b in
            let sa = progress.accuracy(topic: a.id), sb = progress.accuracy(topic: b.id)
            let ra = sa.total == 0 ? 0.5 : sa.ratio
            let rb = sb.total == 0 ? 0.5 : sb.ratio
            return ra < rb
        }
        let topics = Set(ranked.prefix(3).map { $0.id })
        return content.grammar.filter { topics.contains($0.topic) }.shuffled().prefix(15).map { QuizItem(question: $0) }
    }
}

struct LessonRow: View {
    let lesson: Lesson
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        let stat = progress.accuracy(topic: lesson.id)
        let count = content.questions(topic: lesson.id).count
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: stat.ratio, lineWidth: 4, color: stat.total == 0 ? Theme.inkSoft : Theme.ratioColor(stat.ratio))
                Text(stat.total == 0 ? "\(count)" : "\(Int((stat.ratio * 100).rounded()))")
                    .font(.number(12, weight: .semibold))
                    .foregroundColor(stat.total == 0 ? Theme.muted : .primary)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(lesson.title).font(.body.weight(.semibold)).foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Text(stat.total > 0 ? "\(stat.correct) justes sur \(stat.total)" : "\(count) exercices, pas encore commencé")
                    .font(.caption).foregroundColor(Theme.muted)
            }
            Spacer(minLength: 0)
            LevelBadge(level: lesson.level)
        }
        .card(padding: 14)
    }
}

struct LessonView: View {
    let lesson: Lesson
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var speaker: Speaker
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        let questions = content.questions(topic: lesson.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    LevelBadge(level: lesson.level)
                    Text(lesson.title).font(.serif(.largeTitle, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(lesson.summary).font(.body).foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 6)

                ForEach(Array(lesson.rules.enumerated()), id: \.offset) { pair in
                    let rule = pair.element
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Text("\(pair.offset + 1)")
                                .font(.number(14))
                                .foregroundColor(.white)
                                .frame(width: 26, height: 26)
                                .background(Theme.ink, in: Circle())
                            Text(rule.title).font(.serif(.headline))
                        }
                        Text(rule.explanation)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(rule.examples, id: \.self) { ex in
                                Button {
                                    speaker.say(ex, rate: progress.state.speechRate)
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "speaker.wave.2.fill").font(.caption).foregroundColor(Theme.ink).padding(.top, 4)
                                        Text(ex)
                                            .font(.system(.body, design: .serif))
                                            .italic()
                                            .foregroundColor(Theme.ink)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(12)
                                    .background(Theme.inkSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                    .card()
                }

                HStack(alignment: .top, spacing: 12) {
                    Rectangle().fill(Theme.pen).frame(width: 3)
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Le piège du test", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(Theme.pen)
                        Text(lesson.trap)
                            .font(.system(.body, design: .serif))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .card(fill: Theme.penSoft)

                if !questions.isEmpty {
                    NavigationLink {
                        QuizView(title: lesson.title, kind: "Entraînement", examMode: false, items: content.practice(topic: lesson.id))
                    } label: {
                        Label("S'entraîner · \(questions.count) questions", systemImage: "pencil")
                    }
                    .buttonStyle(InkButtonStyle())
                }
            }
            .padding(20)
        }
        .paperBackground()
        .navigationTitle("Leçon")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { speaker.stop() }
    }
}
