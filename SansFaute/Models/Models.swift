import Foundation

// MARK: - Content models (decoded from the bundled JSON files)

struct Rule: Codable, Hashable {
    let title: String
    let explanation: String
    let examples: [String]
}

struct Lesson: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let level: String
    let summary: String
    let rules: [Rule]
    let trap: String
}

struct Question: Codable, Identifiable, Hashable {
    let id: String
    let topic: String
    let level: String
    let prompt: String
    let options: [String]
    let answer: Int
    let explanation: String
}

struct VocabCard: Codable, Identifiable, Hashable {
    let id: String
    let term: String
    let definition: String
    let example: String
    let category: String
    let level: String
}

struct Segment: Codable, Hashable {
    let speaker: String
    let text: String
}

struct ListeningItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let level: String
    let kind: String
    let segments: [Segment]
    let questions: [Question]

    var isDialogue: Bool { Set(segments.map { $0.speaker }).count > 1 }

    var transcript: String {
        if isDialogue {
            return segments.map { "\($0.speaker == "A" ? "—" : "–") \($0.text)" }.joined(separator: "\n\n")
        }
        return segments.map { $0.text }.joined(separator: "\n\n")
    }
}

struct ReadingItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let level: String
    let source: String
    let text: String
    let questions: [Question]
}

struct PlanTask: Codable, Hashable {
    let kind: String
    let minutes: Int
    let label: String
    let ref: String?
}

struct PlanDay: Codable, Identifiable, Hashable {
    let day: Int
    let date: String
    let phase: String
    let tasks: [PlanTask]
    var id: Int { day }
}

// MARK: - Quiz runtime models

/// One question as shown in a quiz, with the audio or text it depends on.
struct QuizItem: Identifiable, Hashable {
    let id: String
    let question: Question
    let segments: [Segment]?
    let passage: String?
    let passageTitle: String?
    /// Questions that share the same audio share a group, so exam mode allows one listening per group.
    let groupId: String?

    init(question: Question, segments: [Segment]? = nil, passage: String? = nil, passageTitle: String? = nil, groupId: String? = nil) {
        self.id = question.id
        self.question = question
        self.segments = segments
        self.passage = passage
        self.passageTitle = passageTitle
        self.groupId = groupId
    }
}

enum Skill: String, CaseIterable, Codable {
    case listening = "CO"
    case structures = "MSL"
    case reading = "CE"
    case vocab = "VOC"

    var title: String {
        switch self {
        case .listening: return "Compréhension orale"
        case .structures: return "Structures de la langue"
        case .reading: return "Compréhension écrite"
        case .vocab: return "Lexique"
        }
    }

    var shortTitle: String {
        switch self {
        case .listening: return "Oral"
        case .structures: return "Structures"
        case .reading: return "Écrit"
        case .vocab: return "Lexique"
        }
    }

    var symbol: String {
        switch self {
        case .listening: return "headphones"
        case .structures: return "textformat"
        case .reading: return "doc.text"
        case .vocab: return "character.book.closed"
        }
    }

    static func of(_ question: Question) -> Skill {
        switch question.topic {
        case "CO": return .listening
        case "CE": return .reading
        case "VOC": return .vocab
        default: return .structures
        }
    }
}

// MARK: - Progress models (persisted)

struct SkillScore: Codable, Hashable {
    var correct: Int = 0
    var total: Int = 0
    var ratio: Double { total == 0 ? 0 : Double(correct) / Double(total) }
}

struct CardState: Codable, Hashable {
    var box: Int
    var due: String
}

struct TestResult: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var kind: String
    var correct: Int
    var total: Int
    var estimate: Int
    var bySkill: [String: SkillScore]
}

enum Level {
    static func weight(_ level: String) -> Double {
        switch level {
        case "C2": return 1.9
        case "C1": return 1.4
        default: return 1.0
        }
    }

    /// Indicative TCF-style score (0 to 699) from weighted accuracy.
    static func estimate(_ answers: [(level: String, correct: Bool)]) -> Int {
        guard !answers.isEmpty else { return 0 }
        var total = 0.0
        var got = 0.0
        for a in answers {
            let w = weight(a.level)
            total += w
            if a.correct { got += w }
        }
        let accuracy = got / total
        let score = 250.0 + 449.0 * accuracy
        return min(699, max(100, Int(score.rounded())))
    }

    static func cefr(_ score: Int) -> String {
        switch score {
        case 600...: return "C2"
        case 500..<600: return "C1"
        case 400..<500: return "B2"
        case 300..<400: return "B1"
        case 200..<300: return "A2"
        default: return "A1"
        }
    }
}
