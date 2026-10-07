import SwiftUI

struct ListeningHomeView: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    private let levels = ["B2", "C1", "C2"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ta priorité : 487 → 500+")
                            .font(.headline)
                        Text("L'oral est ta seule compétence sous le C1. Au TCF tu n'entends chaque document qu'une fois : lis les quatre réponses avant de lancer l'audio, puis écoute pour l'intention et le ton, pas seulement les mots.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    SpeechRateControl()
                }
                ForEach(levels, id: \.self) { level in
                    let items = content.listening.filter { $0.level == level }
                    if !items.isEmpty {
                        Section(header: Text("Niveau \(level)")) {
                            ForEach(items) { item in
                                NavigationLink {
                                    ListeningDetailView(item: item, examDefault: level != "B2")
                                } label: {
                                    ListeningRow(item: item)
                                }
                            }
                        }
                    }
                }
                Section("Écoute réelle, tous les jours") {
                    ExternalLink(title: "France Culture", subtitle: "Débats, entretiens, chroniques. Le niveau C2.", url: "https://www.radiofrance.fr/franceculture")
                    ExternalLink(title: "France Inter", subtitle: "Journaux et chroniques d'actualité.", url: "https://www.radiofrance.fr/franceinter")
                    ExternalLink(title: "RFI", subtitle: "Journal en français, accents variés.", url: "https://www.rfi.fr/fr/")
                    ExternalLink(title: "TV5Monde Apprendre", subtitle: "Exercices de compréhension C1 avec corrigés.", url: "https://apprendre.tv5monde.com/fr")
                }
            }
            .navigationTitle("Écoute")
        }
    }
}

struct ListeningRow: View {
    let item: ListeningItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDialogue ? "person.2.wave.2" : "dot.radiowaves.left.and.right")
                .foregroundColor(Theme.ink)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                Text("\(item.kind) · \(item.questions.count) questions").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            LevelBadge(level: item.level)
        }
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
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.kind).font(.caption.weight(.semibold)).foregroundColor(.secondary)
                        Spacer()
                        LevelBadge(level: item.level)
                    }
                    Text(item.title).font(.title2.weight(.bold))
                }
                .padding(.vertical, 4)
                Picker("Mode", selection: $examMode) {
                    Text("Entraînement").tag(false)
                    Text("Examen").tag(true)
                }
                .pickerStyle(.segmented)
                Text(examMode
                     ? "Une seule écoute, correction à la fin. C'est le vrai format du TCF."
                     : "Écoute autant que tu veux, correction après chaque question, transcription disponible.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section {
                NavigationLink {
                    QuizView(title: item.title, kind: "Entraînement", examMode: examMode, items: content.items(for: item))
                } label: {
                    Label("Écouter et répondre", systemImage: "play.circle.fill")
                        .font(.headline)
                }
            }
            Section("Après les questions") {
                Button {
                    if speaker.isSpeaking { speaker.stop() } else { speaker.speak(item.segments, rate: progress.state.speechRate) }
                } label: {
                    Label(speaker.isSpeaking ? "Arrêter" : "Réécouter en lisant", systemImage: speaker.isSpeaking ? "stop.fill" : "text.bubble")
                }
                DisclosureGroup("Transcription", isExpanded: $showTranscript) {
                    Text(item.transcript)
                        .font(.callout)
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                }
                Text("Méthode des profs : réécoute en lisant, puis une troisième fois sans le texte en répétant juste après la voix (shadowing). C'est ce qui fait progresser le plus vite à l'oral.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Écoute")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { speaker.stop() }
    }
}

struct SpeechRateControl: View {
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Vitesse de la voix")
                Spacer()
                Text(label).foregroundColor(.secondary).font(.subheadline)
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
                        Text(title).foregroundColor(.primary)
                        Text(subtitle).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square").foregroundColor(Theme.ink)
                }
            }
        }
    }
}
