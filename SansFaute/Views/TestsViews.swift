import SwiftUI
import Charts

struct TestsHomeView: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    private var doneToday: Bool {
        let key = DayKey.string(Date())
        return progress.state.results.contains { $0.kind == "Test du jour" && DayKey.string($0.date) == key }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NavigationLink {
                        QuizView(title: "Test du jour", kind: "Test du jour", examMode: false,
                                 items: content.dailyTest(date: Date(), mistakes: progress.state.mistakes), saveResult: true)
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Eyebrow(text: doneToday ? "Fait aujourd'hui" : "15 minutes", color: doneToday ? Theme.good : Theme.muted)
                                Spacer()
                                Image(systemName: doneToday ? "checkmark.seal.fill" : "bolt.fill")
                                    .font(.title2).foregroundColor(doneToday ? Theme.good : Theme.warn)
                            }
                            Text("Test du jour").font(.serif(.title, weight: .bold)).foregroundColor(.primary)
                            Text("Environ 20 questions dans l'ordre du TCF : oral, structures, écrit, lexique. Il reprend tes erreurs passées.")
                                .font(.subheadline).foregroundColor(Theme.muted)
                                .multilineTextAlignment(.leading)
                        }
                        .card(padding: 18)
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 6)

                    VStack(spacing: 10) {
                        NavigationLink {
                            QuizView(title: "Test blanc", kind: "Test blanc", examMode: true, items: content.mockTest(), saveResult: true)
                        } label: {
                            RowCard(symbol: "timer", title: "Test blanc", subtitle: "≈ 45 questions, une seule écoute, correction à la fin", color: Theme.violet)
                        }
                        NavigationLink {
                            QuizView(title: "Série d'écoute", kind: "Entraînement", examMode: true,
                                     items: content.listening.filter { $0.level != "B2" }.shuffled().prefix(4).flatMap { content.items(for: $0) })
                        } label: {
                            RowCard(symbol: "headphones", title: "Série d'écoute", subtitle: "4 documents C1 · C2 en mode examen")
                        }
                        NavigationLink {
                            QuizView(title: "Mes erreurs", kind: "Entraînement", examMode: false,
                                     items: content.mistakeReview(progress.state.mistakes))
                        } label: {
                            RowCard(symbol: "pencil.and.outline", title: "Mes erreurs",
                                    subtitle: progress.state.mistakes.isEmpty ? "Aucune erreur en attente" : "Elles reviennent jusqu'à ce que tu les réussisses",
                                    color: Theme.pen,
                                    trailing: progress.state.mistakes.isEmpty ? nil : "\(progress.state.mistakes.count)")
                        }
                    }
                    .buttonStyle(PressableStyle())

                    SectionHeader(eyebrow: "Progression", title: "Ta courbe")
                    HistoryChart(results: progress.state.results.filter { $0.kind != "Entraînement" })
                        .card()

                    SectionHeader(eyebrow: "\(progress.totalMinutes) minutes au total", title: "Régularité")
                    StudyHeatmap()
                        .card()

                    WeakTopicsCard()

                    SectionHeader(eyebrow: "\(content.reading.count) textes", title: "Compréhension écrite")
                    VStack(spacing: 10) {
                        ForEach(content.reading) { r in
                            NavigationLink {
                                QuizView(title: r.title, kind: "Entraînement", examMode: false, items: content.items(for: r))
                            } label: {
                                HStack(spacing: 14) {
                                    IconBadge(symbol: "doc.text", color: Theme.levelColor(r.level))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.title).font(.body.weight(.semibold)).foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                        Text("\(r.questions.count) questions").font(.caption).foregroundColor(Theme.muted)
                                    }
                                    Spacer(minLength: 0)
                                    LevelBadge(level: r.level)
                                }
                                .card(padding: 14)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }

                    if !progress.state.results.isEmpty {
                        SectionHeader(eyebrow: "Derniers tests", title: "Historique")
                        VStack(spacing: 0) {
                            ForEach(Array(progress.state.results.reversed().prefix(12))) { r in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.kind).font(.subheadline.weight(.semibold))
                                        Text(r.date.formatted(.dateTime.day().month().hour().minute().locale(FR.locale)))
                                            .font(.caption).foregroundColor(Theme.muted)
                                    }
                                    Spacer()
                                    Text("\(r.correct)/\(r.total)").font(.number(14, weight: .regular)).foregroundColor(Theme.muted)
                                    Text("\(r.estimate)").font(.number(17)).foregroundColor(Theme.scoreColor(r.estimate))
                                        .frame(minWidth: 44, alignment: .trailing)
                                }
                                .padding(.vertical, 10)
                                Divider()
                            }
                        }
                        .card(padding: 14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .paperBackground()
            .navigationTitle("Tests")
        }
    }
}

struct HistoryChart: View {
    let results: [TestResult]

    var body: some View {
        if results.count < 2 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ta courbe apparaîtra après deux tests.").font(.subheadline.weight(.semibold))
                Text("Fais le test du jour chaque jour : c'est lui qui mesure ta progression vers 600.")
                    .font(.caption).foregroundColor(Theme.muted)
            }
        } else {
            let recent = Array(results.suffix(20))
            Chart {
                RuleMark(y: .value("C1", 500))
                    .foregroundStyle(Theme.good.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("C1 · 500").font(.caption2).foregroundColor(Theme.good)
                    }
                RuleMark(y: .value("C2", 600))
                    .foregroundStyle(Theme.violet.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("C2 · 600").font(.caption2).foregroundColor(Theme.violet)
                    }
                ForEach(Array(recent.enumerated()), id: \.offset) { pair in
                    AreaMark(x: .value("Test", pair.offset + 1), yStart: .value("Base", 300), yEnd: .value("Score", pair.element.estimate))
                        .foregroundStyle(LinearGradient(colors: [Theme.ink.opacity(0.25), Theme.ink.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Test", pair.offset + 1), y: .value("Score", pair.element.estimate))
                        .foregroundStyle(Theme.ink)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Test", pair.offset + 1), y: .value("Score", pair.element.estimate))
                        .foregroundStyle(Theme.scoreColor(pair.element.estimate))
                        .symbolSize(pair.offset == recent.count - 1 ? 80 : 30)
                }
            }
            .chartYScale(domain: 300...699)
            .chartXAxis(.hidden)
            .frame(height: 190)
        }
    }
}

/// Last five weeks of study, one square per day.
struct StudyHeatmap: View {
    @EnvironmentObject private var progress: ProgressStore

    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Start on the Monday five weeks back so columns line up with weekdays.
        let weekday = (cal.component(.weekday, from: today) + 5) % 7 // Monday = 0
        let start = cal.date(byAdding: .day, value: -(weekday + 28), to: today) ?? today
        return (0..<35).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func color(_ minutes: Int, studied: Bool, future: Bool) -> Color {
        if future { return Color.clear }
        if minutes >= 50 { return Theme.ink }
        if minutes >= 25 { return Theme.ink.opacity(0.7) }
        if minutes >= 10 { return Theme.ink.opacity(0.45) }
        if minutes > 0 || studied { return Theme.ink.opacity(0.25) }
        return Theme.inkSoft
    }

    var body: some View {
        let studied = Set(progress.state.studyDays)
        let todayKey = DayKey.string(Date())
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(["L", "M", "M", "J", "V", "S", "D"].indices, id: \.self) { i in
                    Text(["L", "M", "M", "J", "V", "S", "D"][i])
                        .font(.caption2).foregroundColor(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(days, id: \.self) { d in
                    let key = DayKey.string(d)
                    let future = key > todayKey
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(color(progress.minutes(on: d), studied: studied.contains(key), future: future))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(key == todayKey ? Theme.pen : (future ? Theme.stroke : Color.clear), lineWidth: key == todayKey ? 2 : 1)
                        )
                }
            }
            HStack(spacing: 6) {
                Text("moins").font(.caption2).foregroundColor(Theme.muted)
                ForEach([0.0, 0.25, 0.45, 0.7, 1.0], id: \.self) { o in
                    RoundedRectangle(cornerRadius: 3).fill(o == 0 ? Theme.inkSoft : Theme.ink.opacity(o)).frame(width: 12, height: 12)
                }
                Text("plus").font(.caption2).foregroundColor(Theme.muted)
                Spacer()
                Text("Série : \(progress.streak) j").font(.caption.weight(.semibold)).foregroundColor(Theme.warn)
            }
        }
    }
}

/// Lessons ranked by accuracy, weakest first.
struct WeakTopicsCard: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        let ranked = content.lessons
            .map { (lesson: $0, stat: progress.accuracy(topic: $0.id)) }
            .filter { $0.stat.total >= 2 }
            .sorted { $0.stat.ratio < $1.stat.ratio }
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(eyebrow: "Grammaire", title: "Tes points faibles")
            if ranked.isEmpty {
                Text("Réponds à quelques questions de grammaire : tes leçons les moins réussies apparaîtront ici.")
                    .font(.subheadline).foregroundColor(Theme.muted).card()
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(ranked.prefix(5).enumerated()), id: \.offset) { pair in
                        NavigationLink {
                            LessonView(lesson: pair.element.lesson)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(pair.element.lesson.title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                                    Spacer()
                                    Text("\(Int((pair.element.stat.ratio * 100).rounded())) %")
                                        .font(.number(14))
                                        .foregroundColor(Theme.ratioColor(pair.element.stat.ratio))
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Theme.inkSoft)
                                        Capsule().fill(Theme.ratioColor(pair.element.stat.ratio))
                                            .frame(width: max(4, geo.size.width * CGFloat(pair.element.stat.ratio)))
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .card()
            }
        }
    }
}
