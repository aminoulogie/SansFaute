import Foundation

struct AppState: Codable {
    var doneTasks: [String: [Int]] = [:]
    var cards: [String: CardState] = [:]
    var newCardsByDay: [String: Int] = [:]
    var results: [TestResult] = []
    var topicStats: [String: SkillScore] = [:]
    var mistakes: [String: Int] = [:]
    var studyDays: [String] = []
    var examDate: Date = DayKey.date("2026-11-09") ?? Date()
    var speechRate: Double = 0.9

    init() {}

    // Tolerant decoding so adding fields in a future version never wipes progress.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        doneTasks = (try? c.decodeIfPresent([String: [Int]].self, forKey: .doneTasks)) ?? [:]
        cards = (try? c.decodeIfPresent([String: CardState].self, forKey: .cards)) ?? [:]
        newCardsByDay = (try? c.decodeIfPresent([String: Int].self, forKey: .newCardsByDay)) ?? [:]
        results = (try? c.decodeIfPresent([TestResult].self, forKey: .results)) ?? []
        topicStats = (try? c.decodeIfPresent([String: SkillScore].self, forKey: .topicStats)) ?? [:]
        mistakes = (try? c.decodeIfPresent([String: Int].self, forKey: .mistakes)) ?? [:]
        studyDays = (try? c.decodeIfPresent([String].self, forKey: .studyDays)) ?? []
        examDate = (try? c.decodeIfPresent(Date.self, forKey: .examDate)) ?? (DayKey.date("2026-11-09") ?? Date())
        speechRate = (try? c.decodeIfPresent(Double.self, forKey: .speechRate)) ?? 0.9
    }
}

/// Everything the learner has done, saved on the device.
final class ProgressStore: ObservableObject {
    @Published var state: AppState {
        didSet { save() }
    }

    private let key = "sansfaute.state.v1"
    static let intervals = [0, 1, 2, 4, 7, 15]
    static let newCardsPerDay = 10

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppState.self, from: data) {
            state = decoded
        } else {
            state = AppState()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func reset() {
        let exam = state.examDate
        let rate = state.speechRate
        var fresh = AppState()
        fresh.examDate = exam
        fresh.speechRate = rate
        state = fresh
    }

    // MARK: - Days and streak

    var daysUntilExam: Int {
        let cal = Calendar.current
        let from = cal.startOfDay(for: Date())
        let to = cal.startOfDay(for: state.examDate)
        return cal.dateComponents([.day], from: from, to: to).day ?? 0
    }

    func markStudied() {
        let today = DayKey.string(Date())
        if !state.studyDays.contains(today) { state.studyDays.append(today) }
    }

    var streak: Int {
        let days = Set(state.studyDays)
        var count = 0
        var day = Date()
        if !days.contains(DayKey.string(day)) {
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        while days.contains(DayKey.string(day)) {
            count += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    // MARK: - Plan tasks

    func isDone(day: String, index: Int) -> Bool {
        state.doneTasks[day, default: []].contains(index)
    }

    func toggle(day: String, index: Int) {
        var list = state.doneTasks[day, default: []]
        if let i = list.firstIndex(of: index) {
            list.remove(at: i)
        } else {
            list.append(index)
            markStudied()
        }
        state.doneTasks[day] = list
    }

    // MARK: - Answers

    func record(_ question: Question, correct: Bool) {
        var stat = state.topicStats[question.topic, default: SkillScore()]
        stat.total += 1
        if correct { stat.correct += 1 }
        state.topicStats[question.topic] = stat

        if correct {
            if let n = state.mistakes[question.id] {
                if n <= 1 { state.mistakes.removeValue(forKey: question.id) } else { state.mistakes[question.id] = n - 1 }
            }
        } else {
            state.mistakes[question.id, default: 0] += 1
        }
        markStudied()
    }

    func save(result: TestResult) {
        state.results.append(result)
        if state.results.count > 200 { state.results.removeFirst(state.results.count - 200) }
    }

    func accuracy(topic: String) -> SkillScore {
        state.topicStats[topic] ?? SkillScore()
    }

    /// Average estimate per skill over the last few tests.
    func recentEstimate(_ skill: Skill, last n: Int = 5) -> Int? {
        let relevant = state.results.filter { $0.kind != "Entraînement" }.suffix(n)
        let scores = relevant.compactMap { r -> SkillScore? in
            guard let s = r.bySkill[skill.rawValue], s.total > 0 else { return nil }
            return s
        }
        guard !scores.isEmpty else { return nil }
        let correct = scores.reduce(0) { $0 + $1.correct }
        let total = scores.reduce(0) { $0 + $1.total }
        guard total > 0 else { return nil }
        let accuracy = Double(correct) / Double(total)
        return min(699, max(100, Int((250.0 + 449.0 * accuracy * 1.0).rounded())))
    }

    // MARK: - Flashcards (Leitner boxes)

    func dueCards(from all: [VocabCard], today: Date = Date()) -> [VocabCard] {
        let key = DayKey.string(today)
        return all.filter { card in
            guard let s = state.cards[card.id] else { return false }
            return s.due <= key
        }
    }

    func newCards(from all: [VocabCard], today: Date = Date()) -> [VocabCard] {
        let key = DayKey.string(today)
        let used = state.newCardsByDay[key, default: 0]
        let remaining = max(0, ProgressStore.newCardsPerDay - used)
        return Array(all.filter { state.cards[$0.id] == nil }.prefix(remaining))
    }

    func knownCount(from all: [VocabCard]) -> Int {
        all.filter { (state.cards[$0.id]?.box ?? 0) >= 3 }.count
    }

    func grade(_ card: VocabCard, knew: Bool, today: Date = Date()) {
        let key = DayKey.string(today)
        if state.cards[card.id] == nil {
            state.newCardsByDay[key, default: 0] += 1
        }
        var s = state.cards[card.id] ?? CardState(box: 0, due: key)
        s.box = knew ? min(s.box + 1, ProgressStore.intervals.count - 1) : 0
        let days = knew ? ProgressStore.intervals[s.box] : 0
        let due = Calendar.current.date(byAdding: .day, value: days, to: today) ?? today
        s.due = DayKey.string(due)
        state.cards[card.id] = s
        markStudied()
    }
}
