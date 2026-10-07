import SwiftUI

// MARK: - Dictation

struct DictationHomeView: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("La dictée").font(.serif(.title2, weight: .bold))
                    Text("L'exercice que les profs de FLE utilisent pour l'oral et l'orthographe en même temps. Tu écoutes, tu écris, l'app souligne chaque mot manquant ou faux. Le correcteur du clavier est désactivé.")
                        .font(.subheadline).foregroundColor(Theme.muted)
                    NavigationLink {
                        DictationView(startId: nil)
                    } label: {
                        Label("Dictée au hasard", systemImage: "shuffle")
                    }
                    .buttonStyle(InkButtonStyle(color: Theme.pen))
                }
                .card()

                ForEach(["B2", "C1", "C2"], id: \.self) { level in
                    let items = content.dictation.filter { $0.level == level }
                    if !items.isEmpty {
                        SectionHeader(eyebrow: "\(items.count) phrases", title: "Niveau \(level)")
                        VStack(spacing: 8) {
                            ForEach(items) { item in
                                NavigationLink {
                                    DictationView(startId: item.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.focus).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                                            Text("\(item.text.split(separator: " ").count) mots").font(.caption).foregroundColor(Theme.muted)
                                        }
                                        Spacer()
                                        if let best = progress.state.dictationBest[item.id] {
                                            Text("\(Int((best * 100).rounded())) %")
                                                .font(.number(14, weight: .semibold))
                                                .foregroundColor(Theme.ratioColor(best))
                                        }
                                        LevelBadge(level: item.level)
                                    }
                                    .card(padding: 14)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .paperBackground()
        .navigationTitle("Dictée")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DiffWord: Identifiable {
    let id = UUID()
    let text: String
    let ok: Bool
}

enum DictationDiff {
    static func tokens(_ s: String) -> [String] {
        let cleaned = s
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "'", with: "' ")
        let strip = CharacterSet(charactersIn: ".,;:!?«»\"()…")
        return cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: strip) }
            .filter { !$0.isEmpty }
    }

    /// Longest common subsequence on words (case-insensitive, accents count).
    static func compare(reference: String, answer: String) -> (ref: [DiffWord], typed: [DiffWord], score: Double) {
        let r = tokens(reference)
        let a = tokens(answer)
        let rl = r.map { $0.lowercased() }
        let al = a.map { $0.lowercased() }
        let n = r.count, m = a.count
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0 && m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    dp[i][j] = rl[i] == al[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }
        var refOk = Array(repeating: false, count: n)
        var ansOk = Array(repeating: false, count: m)
        var i = 0, j = 0
        while i < n && j < m {
            if rl[i] == al[j] {
                refOk[i] = true; ansOk[j] = true; i += 1; j += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        let refWords = r.indices.map { DiffWord(text: r[$0], ok: refOk[$0]) }
        let typedWords = a.indices.map { DiffWord(text: a[$0], ok: ansOk[$0]) }
        let matched = refOk.filter { $0 }.count
        let extra = ansOk.filter { !$0 }.count
        let score = n == 0 ? 0 : max(0, Double(matched - extra / 2) / Double(n))
        return (refWords, typedWords, min(1, score))
    }

    static func text(_ words: [DiffWord], okColor: Color, badColor: Color, strikeBad: Bool) -> Text {
        var t = Text("")
        for (k, w) in words.enumerated() {
            var piece = Text(w.text).foregroundColor(w.ok ? okColor : badColor)
            if !w.ok {
                piece = piece.fontWeight(.bold)
                if strikeBad { piece = piece.strikethrough(true, color: badColor) } else { piece = piece.underline(true, color: badColor) }
            }
            t = t + piece + Text(k == words.count - 1 || w.text.hasSuffix("'") ? "" : " ")
        }
        return t
    }
}

struct DictationView: View {
    let startId: String?

    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var speaker: Speaker

    @State private var item: DictationItem? = nil
    @State private var answer = ""
    @State private var checked = false
    @State private var plays = 0
    @State private var showHint = false
    @State private var startedAt = Date()
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            if let item = item {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        LevelBadge(level: item.level)
                        Spacer()
                        Text(plays == 0 ? "pas encore écouté" : "\(plays) écoute\(plays > 1 ? "s" : "")")
                            .font(.caption).foregroundColor(Theme.muted)
                    }
                    HStack(spacing: 10) {
                        Button {
                            play(item, slow: false)
                        } label: {
                            Label(speaker.isSpeaking ? "Arrêter" : "Écouter", systemImage: speaker.isSpeaking ? "stop.fill" : "play.fill")
                        }
                        .buttonStyle(InkButtonStyle())
                        Button {
                            play(item, slow: true)
                        } label: {
                            Label("Lentement", systemImage: "tortoise.fill")
                        }
                        .buttonStyle(SoftButtonStyle())
                        .frame(maxWidth: 150)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: "Ta dictée")
                        TextField("Écris ce que tu entends…", text: $answer, axis: .vertical)
                            .lineLimit(3...8)
                            .font(.system(.title3, design: .serif))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.sentences)
                            .focused($focused)
                            .disabled(checked)
                            .padding(14)
                            .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(focused ? Theme.ink : Theme.stroke, lineWidth: 1.2))
                    }

                    if !checked {
                        Button {
                            showHint.toggle()
                        } label: {
                            Label(showHint ? item.focus : "Indice : sur quoi porte la phrase ?", systemImage: "lightbulb")
                                .font(.footnote)
                        }
                        .foregroundColor(Theme.warn)

                        Button {
                            focused = false
                            check(item)
                        } label: {
                            Label("Corriger", systemImage: "pencil.and.outline")
                        }
                        .buttonStyle(InkButtonStyle(color: Theme.pen))
                        .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)
                    } else {
                        correction(item)
                    }
                }
                .padding(20)
            }
        }
        .paperBackground()
        .navigationTitle("Dictée")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if item == nil {
                item = content.dictation.first { $0.id == startId } ?? content.dictation.randomElement()
            }
        }
        .onDisappear { speaker.stop() }
    }

    private func correction(_ item: DictationItem) -> some View {
        let diff = DictationDiff.compare(reference: item.text, answer: answer)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int((diff.score * 100).rounded())) %")
                    .font(.number(40))
                    .foregroundColor(Theme.ratioColor(diff.score))
                Text(diff.score >= 0.999 ? "Sans faute !" : "de mots justes")
                    .font(.subheadline).foregroundColor(Theme.muted)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Le texte", color: Theme.good)
                DictationDiff.text(diff.ref, okColor: .primary, badColor: Theme.good, strikeBad: false)
                    .font(.system(.title3, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Soulignés : les mots que tu as manqués ou mal écrits.").font(.caption2).foregroundColor(Theme.muted)
            }
            .card(fill: Theme.goodSoft)
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Ta copie", color: Theme.pen)
                DictationDiff.text(diff.typed, okColor: .primary, badColor: Theme.pen, strikeBad: true)
                    .font(.system(.title3, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card(fill: Theme.penSoft)
            Label(item.focus, systemImage: "lightbulb.fill").font(.subheadline).foregroundColor(Theme.warn)
            HStack(spacing: 10) {
                Button {
                    answer = ""
                    checked = false
                    plays = 0
                } label: {
                    Label("Refaire", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(SoftButtonStyle())
                Button {
                    next(after: item)
                } label: {
                    Label("Phrase suivante", systemImage: "arrow.right")
                }
                .buttonStyle(InkButtonStyle())
            }
        }
    }

    private func play(_ item: DictationItem, slow: Bool) {
        if speaker.isSpeaking { speaker.stop(); return }
        plays += 1
        speaker.say(item.text, rate: slow ? 0.65 : progress.state.speechRate)
    }

    private func check(_ item: DictationItem) {
        let diff = DictationDiff.compare(reference: item.text, answer: answer)
        progress.state.dictationBest[item.id] = max(diff.score, progress.state.dictationBest[item.id] ?? 0)
        progress.addStudy(seconds: Int(Date().timeIntervalSince(startedAt)))
        diff.score >= 0.999 ? Haptics.success() : Haptics.error()
        withAnimation { checked = true }
    }

    private func next(after current: DictationItem) {
        let same = content.dictation.filter { $0.level == current.level && $0.id != current.id }
        item = same.randomElement() ?? content.dictation.randomElement()
        answer = ""
        checked = false
        plays = 0
        showHint = false
        startedAt = Date()
    }
}

// MARK: - Shadowing

struct ShadowingPickerView: View {
    @EnvironmentObject private var content: ContentStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Choisis un document. Tu l'écouteras phrase par phrase, en répétant chacune à voix haute juste après la voix : c'est le shadowing, la technique la plus rapide pour l'oral.")
                    .font(.subheadline).foregroundColor(Theme.muted)
                    .card()
                ForEach(content.listening) { item in
                    NavigationLink {
                        ShadowingView(item: item)
                    } label: {
                        RowCard(symbol: item.isDialogue ? "person.2.wave.2" : "waveform", title: item.title,
                                subtitle: "\(item.kind) · \(content.sentences(of: item).count) phrases",
                                color: Theme.levelColor(item.level))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(20)
        }
        .paperBackground()
        .navigationTitle("Phrase par phrase")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ShadowingView: View {
    let item: ListeningItem
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var speaker: Speaker

    @State private var current: Int? = nil
    @State private var hideText = true
    @State private var revealed: Set<Int> = []
    @State private var startedAt = Date()

    var body: some View {
        let sentences = content.sentences(of: item)
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.serif(.title3))
                        Text("\(sentences.count) phrases").font(.caption).foregroundColor(Theme.muted)
                    }
                    Spacer()
                    Toggle("Cacher", isOn: $hideText).labelsHidden()
                    Text(hideText ? "texte caché" : "texte visible").font(.caption).foregroundColor(Theme.muted)
                }
                .card()

                ForEach(sentences.indices, id: \.self) { i in
                    let s = sentences[i]
                    let hidden = hideText && !revealed.contains(i)
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            current = i
                            speaker.say(s.text, rate: progress.state.speechRate)
                        } label: {
                            Image(systemName: current == i && speaker.isSpeaking ? "speaker.wave.3.fill" : "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(s.speaker == "B" ? Theme.violet : Theme.ink)
                        }
                        .buttonStyle(.plain)
                        Text(s.text)
                            .font(.system(.body, design: .serif))
                            .blur(radius: hidden ? 6 : 0)
                            .fixedSize(horizontal: false, vertical: true)
                            .onTapGesture {
                                if revealed.contains(i) { revealed.remove(i) } else { revealed.insert(i) }
                            }
                        Spacer(minLength: 0)
                    }
                    .card(padding: 14, fill: current == i ? Theme.inkSoft : Theme.card)
                }

                if let c = current, c + 1 < sentences.count {
                    Button {
                        current = c + 1
                        speaker.say(sentences[c + 1].text, rate: progress.state.speechRate)
                    } label: {
                        Label("Phrase suivante", systemImage: "forward.fill")
                    }
                    .buttonStyle(InkButtonStyle())
                }
                Text("Touche une phrase floue pour la révéler.")
                    .font(.caption).foregroundColor(Theme.muted)
            }
            .padding(20)
        }
        .paperBackground()
        .navigationTitle("Phrase par phrase")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            speaker.stop()
            progress.addStudy(seconds: Int(Date().timeIntervalSince(startedAt)))
        }
    }
}

// MARK: - Sprint

struct SprintView: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    private let duration: TimeInterval = 60

    @State private var pool: [Question] = []
    @State private var index = 0
    @State private var startedAt: Date? = nil
    @State private var correct = 0
    @State private var missed: [Question] = []
    @State private var flash: Color? = nil
    @State private var over = false
    @State private var newRecord = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if over {
                    results
                } else if startedAt == nil {
                    intro
                } else {
                    playing
                }
            }
            .padding(20)
        }
        .paperBackground()
        .overlay { if over && newRecord { Confetti() } }
        .navigationTitle("Sprint 60 s")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var intro: some View {
        VStack(spacing: 14) {
            Image(systemName: "stopwatch").font(.system(size: 54)).foregroundColor(Theme.warn)
            Text("60 secondes").font(.serif(.largeTitle, weight: .bold))
            Text("Un maximum de questions de structures C1 et C2. Pas d'explication pendant le sprint : tout est corrigé à la fin. C'est l'entraînement au rythme du vrai test.")
                .multilineTextAlignment(.center).foregroundColor(Theme.muted)
            Text("Record : \(progress.state.sprintBest)").font(.number(22)).foregroundColor(Theme.warn)
            Button {
                start()
            } label: {
                Label("Partez !", systemImage: "flag.checkered")
            }
            .buttonStyle(InkButtonStyle(color: Theme.warn))
        }
        .card(padding: 22)
        .padding(.top, 30)
    }

    private var playing: some View {
        let q = pool[index % max(1, pool.count)]
        return VStack(alignment: .leading, spacing: 16) {
            TimelineView(.periodic(from: .now, by: 0.2)) { ctx in
                let left = max(0, duration - ctx.date.timeIntervalSince(startedAt ?? ctx.date))
                VStack(spacing: 6) {
                    HStack {
                        Text("\(correct)").font(.number(28)).foregroundColor(Theme.good)
                        Text("justes").font(.caption).foregroundColor(Theme.muted)
                        Spacer()
                        Text("\(Int(left.rounded(.up))) s").font(.number(28)).foregroundColor(left < 10 ? Theme.pen : .primary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.inkSoft)
                            Capsule().fill(left < 10 ? Theme.pen : Theme.warn)
                                .frame(width: geo.size.width * CGFloat(left / duration))
                        }
                    }
                    .frame(height: 8)
                }
                .onChange(of: left == 0) { ended in
                    if ended { finish() }
                }
            }
            Text(q.prompt)
                .font(.serif(.title3))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(fill: flash ?? Theme.card)
            ForEach(Array(q.options.enumerated()), id: \.offset) { pair in
                Button {
                    answer(q, pair.offset)
                } label: {
                    Text(pair.element)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 14)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 6) {
                Text(newRecord ? "Nouveau record !" : "Temps écoulé").font(.serif(.title2, weight: .bold))
                Text("\(correct)").font(.number(64)).foregroundColor(Theme.good)
                Text("bonnes réponses · \(missed.count) erreur\(missed.count > 1 ? "s" : "") · record \(progress.state.sprintBest)")
                    .font(.subheadline).foregroundColor(Theme.muted)
            }
            .frame(maxWidth: .infinity)
            .card(padding: 20)
            if !missed.isEmpty {
                SectionHeader(eyebrow: "Correction", title: "Tes erreurs")
                ForEach(missed) { q in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(q.prompt).font(.subheadline.weight(.semibold))
                        Text("Réponse : \(q.options[q.answer])").font(.subheadline).foregroundColor(Theme.good)
                        Text(q.explanation).font(.caption).foregroundColor(Theme.muted)
                    }
                    .card(padding: 14)
                }
            }
            Button {
                start()
            } label: {
                Label("Rejouer", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(InkButtonStyle(color: Theme.warn))
        }
    }

    private func start() {
        pool = content.sprintPool()
        index = 0
        correct = 0
        missed = []
        over = false
        newRecord = false
        startedAt = Date()
    }

    private func answer(_ q: Question, _ i: Int) {
        guard !over else { return }
        let ok = i == q.answer
        progress.record(q, correct: ok)
        if ok {
            correct += 1
            Haptics.tap()
            flash = Theme.goodSoft
        } else {
            missed.append(q)
            Haptics.error()
            flash = Theme.penSoft
        }
        index += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { flash = nil }
    }

    private func finish() {
        guard !over else { return }
        over = true
        progress.addStudy(seconds: Int(duration))
        if correct > progress.state.sprintBest {
            progress.state.sprintBest = correct
            newRecord = true
            Haptics.success()
        }
    }
}

// MARK: - Traps

struct TrapsView: View {
    @EnvironmentObject private var content: ContentStore
    @State private var page = 0

    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $page) {
                ForEach(Array(content.lessons.enumerated()), id: \.offset) { pair in
                    let lesson = pair.element
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Eyebrow(text: "Piège \(pair.offset + 1) / \(content.lessons.count)", color: Theme.pen)
                            Spacer()
                            LevelBadge(level: lesson.level)
                        }
                        Text(lesson.title).font(.serif(.title2, weight: .bold))
                        HStack(alignment: .top, spacing: 12) {
                            Rectangle().fill(Theme.pen).frame(width: 3)
                            Text(lesson.trap)
                                .font(.system(.title3, design: .serif))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let ex = lesson.rules.first?.examples.first {
                            Text(ex).italic().foregroundColor(Theme.ink)
                        }
                        Spacer()
                        NavigationLink {
                            LessonView(lesson: lesson)
                        } label: {
                            Label("Revoir la leçon", systemImage: "book")
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.stroke))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .tag(pair.offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            Text("Glisse pour passer au piège suivant").font(.caption).foregroundColor(Theme.muted)
                .padding(.bottom, 12)
        }
        .paperBackground()
        .navigationTitle("Pièges flash")
        .navigationBarTitleDisplayMode(.inline)
    }
}
