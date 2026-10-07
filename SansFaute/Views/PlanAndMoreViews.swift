import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    private var phases: [String] {
        var seen: [String] = []
        for d in content.plan where !seen.contains(d.phase) { seen.append(d.phase) }
        return seen
    }

    var body: some View {
        List {
            Section {
                Text("1 heure par jour : 20 min d'écoute, 15 min de grammaire, 10 min de vocabulaire, 15 min de test. Le samedi, un test blanc. Les derniers jours restent légers pour arriver reposé.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            ForEach(phases, id: \.self) { phase in
                Section(phase) {
                    ForEach(content.plan.filter { $0.phase == phase }) { day in
                        NavigationLink {
                            DayDetailView(day: day)
                        } label: {
                            DayRow(day: day)
                        }
                    }
                }
            }
        }
        .navigationTitle("Programme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DayRow: View {
    let day: PlanDay
    @EnvironmentObject private var progress: ProgressStore

    private var doneCount: Int {
        day.tasks.indices.filter { progress.isDone(day: day.date, index: $0) }.count
    }

    private var isToday: Bool { day.date == DayKey.string(Date()) }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel).fontWeight(isToday ? .bold : .regular)
                Text(day.tasks.first?.label ?? "").font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            if isToday {
                Text("Aujourd'hui").font(.caption2.weight(.bold)).foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.ink, in: Capsule())
            }
            Text("\(doneCount)/\(day.tasks.count)")
                .font(.caption.monospacedDigit())
                .foregroundColor(doneCount == day.tasks.count ? Theme.good : .secondary)
        }
    }

    private var dateLabel: String {
        guard let d = DayKey.date(day.date) else { return day.date }
        let s = d.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR")))
        return "J\(day.day) · " + s.prefix(1).uppercased() + String(s.dropFirst())
    }
}

struct DayDetailView: View {
    let day: PlanDay

    var body: some View {
        List {
            Section(day.phase) {
                ForEach(Array(day.tasks.enumerated()), id: \.offset) { pair in
                    TaskRow(day: day, index: pair.offset, task: pair.element)
                }
            }
        }
        .navigationTitle("Jour \(day.day)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ResourcesView: View {
    var body: some View {
        List {
            Section("Ton point de départ") {
                ResultLine(label: "Compréhension orale", score: 487)
                ResultLine(label: "Structures de la langue", score: 518)
                ResultLine(label: "Compréhension écrite", score: 555)
                ResultLine(label: "Global", score: 520)
                Text("Chaque épreuve du TCF est notée sur 699 et le score global est la moyenne des trois. Le C2 commence à 600. Les universités demandent en général 400 (B2), donc ton C1 te suffit déjà pour Campus France : le C2 est un bonus.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Ce qui sépare le C1 du C2") {
                Bullet("Comprendre presque tout sans effort, y compris une conférence spécialisée au débit naturel.")
                Bullet("Saisir l'implicite : ce que le locuteur pense sans le dire, son attitude, son ironie.")
                Bullet("Reconnaître le registre (familier, courant, soutenu) et les expressions idiomatiques.")
                Bullet("Distinguer de fines nuances de sens entre deux mots ou deux structures proches.")
                Bullet("Repérer les effets de style et les temps littéraires dans un texte.")
            }

            Section("Ce que travaillent les profs en préparation C1 · C2") {
                Bullet("Documents authentiques : conférences, débats, podcasts, éditoriaux.")
                Bullet("Décryptage de l'implicite, des registres et de l'ironie.")
                Bullet("Prise de notes pendant l'écoute puis reformulation en quelques phrases.")
                Bullet("Lecture critique : trouver la thèse, les arguments et la position réelle de l'auteur.")
                Bullet("Tests blancs en conditions réelles, puis analyse de chaque erreur.")
                Text("C'est exactement ce que fait cette app : écoute en mode examen, questions d'attitude, leçons sur les pièges, test blanc chaque samedi.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Stratégies le jour J") {
                Bullet("Lis les quatre propositions avant le début de chaque document audio.")
                Bullet("Les questions vont du plus facile au plus difficile : garde ta concentration pour la fin, c'est là que se jouent le C1 et le C2.")
                Bullet("Pour les questions de ton, cherche un adjectif d'attitude (sceptique, ironique, nuancé), pas un résumé du contenu.")
                Bullet("En structures, lis toute la phrase : le mot qui décide du mode est souvent loin du blanc.")
                Bullet("Ne bloque pas plus de 30 secondes sur une question, avance.")
            }

            Section("S'entraîner sur le vrai format") {
                ExternalLink(title: "TCF Tout public (officiel)", subtitle: "France Éducation international, exemples d'épreuves", url: "https://www.france-education-international.fr/test/tcf-tout-public")
                ExternalLink(title: "TV5Monde Apprendre", subtitle: "Exercices C1 audio et vidéo corrigés", url: "https://apprendre.tv5monde.com/fr")
                ExternalLink(title: "RFI Savoirs", subtitle: "Actualité en français facile à avancé", url: "https://savoirs.rfi.fr/fr/apprendre-enseigner")
            }

            Section("Écouter et lire chaque jour") {
                ExternalLink(title: "France Culture", subtitle: "Le meilleur entraînement C2 à l'oral", url: "https://www.radiofrance.fr/franceculture")
                ExternalLink(title: "France Inter", subtitle: "Journaux et chroniques", url: "https://www.radiofrance.fr/franceinter")
                ExternalLink(title: "Le Monde", subtitle: "Éditoriaux et tribunes pour la lecture critique", url: "https://www.lemonde.fr")
                ExternalLink(title: "Courrier international", subtitle: "Presse étrangère traduite, textes argumentatifs", url: "https://www.courrierinternational.com")
            }

            Section("Livres utiles") {
                Bullet("ABC TCF (CLE International) : tests complets avec audio.")
                Bullet("Réussir le TCF (Didier) : méthode et entraînement.")
                Bullet("Grammaire progressive du français, niveau perfectionnement (CLE International).")
                Bullet("Vocabulaire progressif du français, niveau perfectionnement (CLE International).")
            }
        }
        .navigationTitle("Ressources")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ResultLine: View {
    let label: String
    let score: Int
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(score)").monospacedDigit().fontWeight(.semibold).foregroundColor(Theme.scoreColor(score))
            LevelBadge(level: Level.cefr(score))
        }
    }
}

struct Bullet: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Theme.ink).frame(width: 5, height: 5).padding(.top, 7)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var speaker: Speaker
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Examen") {
                DatePicker("Date du TCF", selection: $progress.state.examDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "fr_FR"))
            }
            Section {
                SpeechRateControl()
                Button {
                    speaker.say("Bien qu'il soit tard, nous continuons la réunion, à moins que vous ne préfériez la reporter.", rate: progress.state.speechRate)
                } label: {
                    Label("Tester la voix", systemImage: "speaker.wave.2")
                }
            } header: {
                Text("Voix")
            } footer: {
                Text(Speaker.hasEnhancedVoice
                     ? "Une voix française améliorée est installée."
                     : "Pour une voix plus naturelle : Réglages iPhone › Accessibilité › Contenu énoncé › Voix › Français (France), puis télécharge une voix « améliorée » ou « premium ». L'app l'utilisera automatiquement.")
            }
            Section {
                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    Text("Effacer ma progression")
                }
            } footer: {
                Text("Efface les résultats, les cartes et les erreurs enregistrées. La date d'examen est conservée.")
            }
            Section("À propos") {
                Text("SansFaute · préparation TCF TP, du C1 vers le C2. Contenus originaux rédigés pour l'entraînement. Les scores affichés sont des estimations indicatives, pas des scores officiels.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Effacer toute la progression ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Effacer", role: .destructive) { progress.reset() }
            Button("Annuler", role: .cancel) {}
        }
    }
}
