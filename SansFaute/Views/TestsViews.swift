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
            List {
                Section {
                    NavigationLink {
                        QuizView(title: "Test du jour", kind: "Test du jour", examMode: false,
                                 items: content.dailyTest(date: Date(), mistakes: progress.state.mistakes), saveResult: true)
                    } label: {
                        TestRow(symbol: "bolt.fill", title: "Test du jour",
                                subtitle: doneToday ? "Fait aujourd'hui. Tu peux le refaire." : "Environ 20 questions · 15 min · oral, structures, écrit, lexique",
                                done: doneToday)
                    }
                    NavigationLink {
                        QuizView(title: "Test blanc", kind: "Test blanc", examMode: true, items: content.mockTest(), saveResult: true)
                    } label: {
                        TestRow(symbol: "timer", title: "Test blanc",
                                subtitle: "Environ 45 questions · 45 min · une seule écoute, correction à la fin",
                                done: false)
                    }
                    NavigationLink {
                        QuizView(title: "Oral · mode examen", kind: "Entraînement", examMode: true,
                                 items: content.listening.filter { $0.level != "B2" }.shuffled().prefix(4).flatMap { content.items(for: $0) })
                    } label: {
                        TestRow(symbol: "headphones", title: "Série d'écoute", subtitle: "4 documents C1 et C2, une seule écoute", done: false)
                    }
                    NavigationLink {
                        QuizView(title: "Mes erreurs", kind: "Entraînement", examMode: false,
                                 items: content.mistakeReview(progress.state.mistakes))
                    } label: {
                        TestRow(symbol: "pencil.and.outline", title: "Mes erreurs",
                                subtitle: progress.state.mistakes.isEmpty ? "Aucune erreur en attente" : "\(progress.state.mistakes.count) questions à reprendre",
                                done: false)
                    }
                }

                Section("Progression") {
                    HistoryChart(results: progress.state.results.filter { $0.kind != "Entraînement" })
                }

                Section("Compréhension écrite") {
                    ForEach(content.reading) { r in
                        NavigationLink {
                            QuizView(title: r.title, kind: "Entraînement", examMode: false, items: content.items(for: r))
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.title)
                                    Text(r.source).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                LevelBadge(level: r.level)
                            }
                        }
                    }
                }

                if !progress.state.results.isEmpty {
                    Section("Historique") {
                        ForEach(Array(progress.state.results.reversed().prefix(15))) { r in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.kind)
                                    Text(r.date.formatted(.dateTime.day().month().hour().minute().locale(Locale(identifier: "fr_FR"))))
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(r.correct)/\(r.total)").monospacedDigit().foregroundColor(.secondary)
                                Text("\(r.estimate)").monospacedDigit().fontWeight(.semibold)
                                    .foregroundColor(Theme.scoreColor(r.estimate))
                                    .frame(minWidth: 40, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tests")
        }
    }
}

struct TestRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    let done: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(done ? Theme.good : Theme.ink, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct HistoryChart: View {
    let results: [TestResult]

    var body: some View {
        if results.count < 2 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ta courbe apparaîtra après deux tests.")
                    .font(.subheadline)
                Text("Fais le test du jour chaque jour : c'est lui qui mesure ta progression vers 600.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        } else {
            let recent = Array(results.suffix(20))
            Chart {
                RuleMark(y: .value("C1", 500))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("C1").font(.caption2).foregroundColor(.secondary)
                    }
                RuleMark(y: .value("C2", 600))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("C2").font(.caption2).foregroundColor(.secondary)
                    }
                ForEach(Array(recent.enumerated()), id: \.offset) { pair in
                    LineMark(x: .value("Test", pair.offset + 1), y: .value("Score", pair.element.estimate))
                        .foregroundStyle(Theme.ink)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Test", pair.offset + 1), y: .value("Score", pair.element.estimate))
                        .foregroundStyle(Theme.scoreColor(pair.element.estimate))
                }
            }
            .chartYScale(domain: 300...699)
            .chartXAxis(.hidden)
            .frame(height: 180)
            .padding(.vertical, 6)
        }
    }
}
