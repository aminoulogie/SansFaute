import SwiftUI

struct ListeningHomeView: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var accuracy: SkillScore { progress.accuracy(topic: "CO") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Eyebrow(text: "Ta priorité", color: Theme.pen)
                                Text("487 → 500+").font(.system(size: 38, weight: .black, design: .serif)).foregroundColor(Theme.ink)
                                Text("L'oral est ta seule épreuve sous le C1.").font(.subheadline).foregroundColor(Theme.muted)
                            }
                            Spacer()
                            ZStack {
                                ProgressRing(progress: accuracy.ratio, lineWidth: 8, color: Theme.ratioColor(accuracy.ratio))
                                Text(accuracy.total == 0 ? "–" : "\(Int((accuracy.ratio * 100).rounded()))%").font(.number(16))
                            }
                            .frame(width: 64, height: 64)
                        }
                        Text("Au TCF, tu n'entends chaque document qu'une fois. Lis les quatre réponses avant de lancer l'audio, puis écoute pour l'intention et le ton, pas seulement les mots.")
                            .font(.footnote).foregroundColor(Theme.muted)
                        SpeechRateControl()
                    }
                    .card(padding: 18)
                    .padding(.top, 6)

                    LazyVGrid(columns: columns, spacing: 12) {
                        NavigationLink { DictationHomeView() } label: {
                            Tile(symbol: "pencil.line", title: "Dictée", subtitle: "\(content.dictation.count) phrases piégées", color: Theme.pen)
                        }
                        NavigationLink { ShadowingPickerView() } label: {
                            Tile(symbol: "waveform", title: "Phrase par phrase", subtitle: "Shadowing guidé", color: Theme.ink)
                        }
                    }
                    .buttonStyle(PressableStyle())

                    ForEach(["B2", "C1", "C2"], id: \.self) { level in
                        let items = content.listening.filter { $0.level == level }
                        if !items.isEmpty {
                            SectionHeader(eyebrow: "\(items.count) documents", title: "Niveau \(level)")
                            VStack(spacing: 10) {
                                ForEach(items) { item in
                                    NavigationLink {
                                        ListeningDetailView(item: item, examDefault: level != "B2")
                                    } label: {
                                        ListeningRow(item: item)
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                    }

                    SectionHeader(eyebrow: "Tous les jours, 10 minutes", title: "Écoute réelle")
                    VStack(spacing: 0) {
                        ExternalLink(title: "France Culture", subtitle: "Débats, entretiens, chroniques. Le niveau C2.", url: "https://www.radiofrance.fr/franceculture")
                        Divider().padding(.vertical, 10)
                        ExternalLink(title: "France Inter", subtitle: "Journaux et chroniques d'actualité.", url: "https://www.radiofrance.fr/franceinter")
                        Divider().padding(.vertical, 10)
                        ExternalLink(title: "RFI", subtitle: "Journal en français, accents variés.", url: "https://www.rfi.fr/fr/")
                        Divider().padding(.vertical, 10)
                        ExternalLink(title: "TV5Monde Apprendre", subtitle: "Exercices C1 corrigés.", url: "https://apprendre.tv5monde.com/fr")
                    }
                    .card()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .paperBackground()
            .navigationTitle("Écoute")
        }
    }
}

struct ListeningRow: View {
    let item: ListeningItem
    @EnvironmentObject private var progress: ProgressStore

    private var status: (String, Color)? {
        let ids = item.questions.map { $0.id }
        let wrong = ids.filter { progress.state.mistakes[$0] != nil }.count
        if wrong > 0 { return ("\(wrong) à revoir", Theme.pen) }
        return nil
    }

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(symbol: item.isDialogue ? "person.2.wave.2" : "dot.radiowaves.left.and.right",
                      color: Theme.levelColor(item.level))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.body.weight(.semibold)).foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text("\(item.kind) · \(item.questions.count) questions").font(.caption).foregroundColor(Theme.muted)
                    if let s = status {
                        Text(s.0).font(.caption.weight(.semibold)).foregroundColor(s.1)
                    }
                }
            }
            Spacer(minLength: 0)
            LevelBadge(level: item.level)
        }
        .card(padding: 14)
    }
}

struct ListeningDetailView: View {
    let item: ListeningItem
    @State private var examMode: Bool
    @State private var showTranscript = false

    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var speaker: Speaker
    @EnvironmentObject private var progress: ProgressStore

    init(item: ListeningItem, examDefault: Bool) {
        self.item = item
        _examMode = State(initialValue: examDefault)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Eyebrow(text: item.kind)
                        Spacer()
                        LevelBadge(level: item.level)
                    }
                    Text(item.title).font(.serif(.title, weight: .bold))
                    Text("\(item.questions.count) questions · \(item.isDialogue ? "dialogue à deux voix" : "une voix")")
                        .font(.subheadline).foregroundColor(Theme.muted)
                }
                .card(padding: 18)

                VStack(alignment: .leading, spacing: 10) {
                    Picker("Mode", selection: $examMode) {
                        Text("Entraînement").tag(false)
                        Text("Examen").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Text(examMode
                         ? "Une seule écoute, correction à la fin. Le vrai format du TCF."
                         : "Réécoute libre, correction après chaque question, transcription.")
                        .font(.caption).foregroundColor(Theme.muted)
                    NavigationLink {
                        QuizView(title: item.title, kind: "Entraînement", examMode: examMode, items: content.items(for: item))
                    } label: {
                        Label("Écouter et répondre", systemImage: "play.fill")
                    }
                    .buttonStyle(InkButtonStyle())
                }
                .card()

                SectionHeader(eyebrow: "Après les questions", title: "Travailler le document")
                NavigationLink {
                    ShadowingView(item: item)
                } label: {
                    RowCard(symbol: "waveform", title: "Phrase par phrase", subtitle: "Réécoute chaque phrase et répète-la à voix haute")
                }
                .buttonStyle(PressableStyle())

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Transcription").font(.headline)
                        Spacer()
                        Button {
                            if speaker.isSpeaking { speaker.stop() } else { speaker.speak(item.segments, rate: progress.state.speechRate) }
                        } label: {
                            Image(systemName: speaker.isSpeaking ? "stop.circle.fill" : "play.circle.fill").font(.title2)
                        }
                        Button {
                            withAnimation { showTranscript.toggle() }
                        } label: {
                            Image(systemName: showTranscript ? "eye.slash" : "eye").font(.title3)
                        }
                    }
                    if showTranscript {
                        Text(item.transcript)
                            .font(.system(.body, design: .serif))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Masquée pour ne pas te donner les réponses. Touche l'œil après avoir répondu.")
                            .font(.caption).foregroundColor(Theme.muted)
                    }
                }
                .card()
            }
            .padding(20)
        }
        .paperBackground()
        .navigationTitle("Écoute")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { speaker.stop() }
    }
}

struct SpeechRateControl: View {
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "speedometer").foregroundColor(Theme.ink)
                Text("Vitesse de la voix").font(.subheadline)
                Spacer()
                Text(label).font(.caption.weight(.semibold)).foregroundColor(Theme.ink)
            }
            Slider(value: $progress.state.speechRate, in: 0.75...1.2, step: 0.05)
        }
    }

    private var label: String {
        let r = progress.state.speechRate
        if r < 0.85 { return "lente" }
        if r < 1.0 { return "naturelle" }
        if r < 1.1 { return "rapide" }
        return "très rapide"
    }
}

struct ExternalLink: View {
    let title: String
    let subtitle: String
    let url: String

    var body: some View {
        if let u = URL(string: url) {
            Link(destination: u) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                        Text(subtitle).font(.caption).foregroundColor(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundColor(Theme.ink)
                }
            }
        }
    }
}
