import Foundation

/// Loads every piece of bundled course content once.
final class ContentStore: ObservableObject {
    let lessons: [Lesson]
    let grammar: [Question]
    let vocab: [VocabCard]
    let listening: [ListeningItem]
    let reading: [ReadingItem]
    let plan: [PlanDay]

    /// Every question in the app, keyed by id, already wrapped with its audio or text.
    let itemsById: [String: QuizItem]

    init() {
        lessons = ContentStore.load("lessons")
        grammar = ContentStore.load("grammar")
        vocab = ContentStore.load("vocab")
        listening = ContentStore.load("listening")
        reading = ContentStore.load("reading")
        plan = ContentStore.load("plan")

        var map: [String: QuizItem] = [:]
        for q in grammar { map[q.id] = QuizItem(question: q) }
        for l in listening {
            for q in l.questions { map[q.id] = QuizItem(question: q, segments: l.segments, groupId: l.id) }
        }
        for r in reading {
            for q in r.questions { map[q.id] = QuizItem(question: q, passage: r.text, passageTitle: r.title, groupId: r.id) }
        }
        itemsById = map
    }

    private static func load<T: Decodable>(_ name: String) -> [T] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Missing resource \(name).json")
            return []
        }
        do {
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            print("Could not decode \(name).json: \(error)")
            return []
        }
    }

    func lesson(_ id: String?) -> Lesson? { lessons.first { $0.id == id } }
    func listeningItem(_ id: String?) -> ListeningItem? { listening.first { $0.id == id } }
    func readingItem(_ id: String?) -> ReadingItem? { reading.first { $0.id == id } }
    func questions(topic: String) -> [Question] { grammar.filter { $0.topic == topic } }

    func planDay(for date: Date) -> PlanDay? {
        let key = DayKey.string(date)
        return plan.first { $0.date == key }
    }

    // MARK: - Quiz builders

    func items(for listening: ListeningItem) -> [QuizItem] {
        listening.questions.map { QuizItem(question: $0, segments: listening.segments, groupId: listening.id) }
    }

    func items(for reading: ReadingItem) -> [QuizItem] {
        reading.questions.map { QuizItem(question: $0, passage: reading.text, passageTitle: reading.title, groupId: reading.id) }
    }

    /// Multiple-choice question generated from a vocabulary card.
    func vocabQuestion(for card: VocabCard, rng: inout SeededRNG) -> QuizItem {
        let pool = vocab.filter { $0.id != card.id && $0.category != "Paronymes" }
        let sameCategory = pool.filter { $0.category == card.category }
        var distractors = Array(sameCategory.shuffled(using: &rng).prefix(3))
        if distractors.count < 3 {
            let extra = pool.filter { c in !distractors.contains(where: { $0.id == c.id }) }.shuffled(using: &rng)
            distractors.append(contentsOf: extra.prefix(3 - distractors.count))
        }
        var options = distractors.map { $0.term }
        options.append(card.term)
        options.shuffle(using: &rng)
        let answer = options.firstIndex(of: card.term) ?? 0
        let q = Question(
            id: "voc-\(card.id)",
            topic: "VOC",
            level: card.level,
            prompt: "Quel terme correspond à cette définition ?\n« \(card.definition) »",
            options: options,
            answer: answer,
            explanation: "\(card.term) : \(card.example)"
        )
        return QuizItem(question: q)
    }

    /// The test of the day: about 20 questions, the same all day, weighted toward your mistakes.
    func dailyTest(date: Date, mistakes: [String: Int]) -> [QuizItem] {
        var rng = SeededRNG(seed: DayKey.seed(date))
        var result: [QuizItem] = []

        // Listening first, like the real TCF.
        for l in listening.shuffled(using: &rng).prefix(2) { result.append(contentsOf: items(for: l)) }

        // Grammar: up to 3 past mistakes, then fill with C1 and C2.
        let shuffled = grammar.shuffled(using: &rng)
        let weak = shuffled.filter { mistakes[$0.id] != nil }.prefix(3)
        var chosen = Array(weak)
        for q in shuffled where chosen.count < 8 {
            if chosen.contains(where: { $0.id == q.id }) { continue }
            if q.level == "B2" && chosen.count < 7 { continue }
            chosen.append(q)
        }
        result.append(contentsOf: chosen.map { QuizItem(question: $0) })

        // Reading
        if let r = reading.shuffled(using: &rng).first { result.append(contentsOf: items(for: r)) }

        // Vocabulary
        let cards = vocab.filter { $0.category != "Paronymes" }.shuffled(using: &rng).prefix(4)
        for c in cards { result.append(vocabQuestion(for: c, rng: &rng)) }
        return result
    }

    /// A longer mock exam in TCF order: listening, structures, reading.
    func mockTest() -> [QuizItem] {
        var rng = SeededRNG(seed: UInt64(Date().timeIntervalSince1970))
        var result: [QuizItem] = []
        for l in listening.filter({ $0.level != "B2" }).shuffled(using: &rng).prefix(5) {
            result.append(contentsOf: items(for: l))
        }
        let g = grammar.shuffled(using: &rng).prefix(15)
        result.append(contentsOf: g.map { QuizItem(question: $0) })
        let cards = vocab.filter { $0.category != "Paronymes" }.shuffled(using: &rng).prefix(5)
        for c in cards { result.append(vocabQuestion(for: c, rng: &rng)) }
        for r in reading.shuffled(using: &rng).prefix(3) { result.append(contentsOf: items(for: r)) }
        return result
    }

    func practice(topic: String) -> [QuizItem] {
        var rng = SeededRNG(seed: UInt64(Date().timeIntervalSince1970))
        return questions(topic: topic).shuffled(using: &rng).map { QuizItem(question: $0) }
    }

    func mistakeReview(_ mistakes: [String: Int]) -> [QuizItem] {
        mistakes
            .sorted { $0.value > $1.value }
            .compactMap { itemsById[$0.key] }
    }
}

// MARK: - Helpers

enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func string(_ date: Date) -> String { formatter.string(from: date) }
    static func date(_ string: String) -> Date? { formatter.date(from: string) }

    static func seed(_ date: Date) -> UInt64 {
        let digits = string(date).replacingOccurrences(of: "-", with: "")
        return UInt64(digits) ?? 1
    }
}

/// Small deterministic generator so the test of the day stays the same all day.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
