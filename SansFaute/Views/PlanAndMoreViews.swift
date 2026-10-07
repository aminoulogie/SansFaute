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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("1 heure par jour : 20 min d'écoute, 15 min de grammaire, 10 min de vocabulaire, 15 min de test. Le samedi, un test blanc. Les derniers jours restent légers pour arriver reposé.")
                    .font(.subheadline).foregroundColor(Theme.muted)
                    .card()
                ForEach(phases, id: \.self) { phase in
                    let parts = phase.components(separatedBy: " · ")
                    SectionHeader(eyebrow: parts.first ?? "", title: parts.count > 1 ? parts[1] : phase)
                    VStack(spacing: 8) {
                        ForEach(content.plan.filter { $0.phase == phase }) { day in
                            NavigationLink {
                                DayDetailView(day: day)
                            } label: {
                                DayRow(day: day)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }
            .padding(20)
        }
        .paperBackground()
        .navigationTitle("Programme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DayRow: View {
    let day: PlanDay
    @EnvironmentObject private var progress: ProgressStore

    private var isToday: Bool { day.date == DayKey.string(Date()) }
    private var isPast: Bool { day.date < DayKey.string(Date()) }

    var body: some View {
        let ratio = progress.doneRatio(for: day)
        let d = DayKey.date(day.date) ?? Date()
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(d.formatted(.dateTime.weekday(.abbreviated).locale(FR.locale)).uppercased())
                    .font(.system(size: 10, weight: .bold)).foregroundColor(isToday ? .white : Theme.muted)
                Text(d.formatted(.dateTime.day()))
                    .font(.number(20)).foregroundColor(isToday ? .white : .primary)
            }
            .frame(width: 46, height: 46)
            .background(isToday ? Theme.ink : Theme.inkSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("Jour \(day.day)").font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                Text(day.tasks.first?.label ?? "").font(.caption).foregroundColor(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
            ZStack {
                ProgressRing(progress: ratio, lineWidth: 4, color: ratio >= 1 ? Theme.good : Theme.ink)
                if ratio >= 1 {
                    Image(systemName: "checkmark").font(.caption2.weight(.heavy)).foregroundColor(Theme.good)
                }
            }
            .frame(width: 28, height: 28)
            .opacity(isPast || isToday || ratio > 0 ? 1 : 0.35)
        }
        .card(padding: 12)
    }
}

struct DayDetailView: View {
    let day: PlanDay

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(eyebrow: day.phase, title: FR.longDate(DayKey.date(day.date) ?? Date()))
                ForEach(Array(day.tasks.enumerated()), id: \.offset) { pair in
                    TaskCard(day: day, index: pair.offset, task: pair.element)
                }
                NavigationLink {
                    GuidedSessionView(day: day)
                } label: {
                    Label("Faire cette séance en mode guidé", systemImage: "play.fill")
                }
                .buttonStyle(InkButtonStyle())
                .padding(.top, 6)
            }
            .padding(20)
        }
        .paperBackground()
        .navigationTitle("Jour \(day.day)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ResourcesView: View {
    @EnvironmentObject private var progress: ProgressStore

    private let checklist = [
        "Convocation imprimée",
        "Passeport en cours de validité",
        "Trajet repéré, arrivée 30 minutes avant",
        "Montre sans écran ou repère de temps",
        "Nuit complète la veille",
        "Petit-déjeuner et bouteille d'eau",
        "Dossier Campus France prêt à recevoir le résultat"
    ]

    var body: some View {
        List {
            Section("Ton point de départ") {
                ResultLine(label: "Compréhension orale", score: 487)
                ResultLine(label: "Structures de la langue", score: 518)
                ResultLine(label: "Compréhension écrite", score: 555)
                ResultLine(label: "Global", score: 520)
                Text("Chaque épreuve du TCF est notée sur 699 et le score global est la moyenne des trois. Le C2 commence à 600. Les universités demandent en général 400 (B2), donc ton C1 te suffit déjà pour Campus France : le C2 est un bonus.")
                    .font(.caption).foregroundColor(Theme.muted)
            }

            Section("Check-list du jour J") {
                ForEach(checklist, id: \.self) { item in
                    Button {
                        Haptics.tap()
                        progress.toggleCheck(item)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: progress.isChecked(item) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(progress.isChecked(item) ? Theme.good : Theme.muted)
                                .font(.title3)
                            Text(item).foregroundColor(.primary)
                                .strikethrough(progress.isChecked(item), color: Theme.muted)
                        }
                    }
                }
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
                Bullet("Dictées ciblées sur les accords et les homophones.")
                Bullet("Lecture critique : trouver la thèse, les arguments et la position réelle de l'auteur.")
                Bullet("Tests blancs en conditions réelles, puis analyse de chaque erreur.")
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
                ExternalLink(title: "RFI Savoirs", subtitle: "Actualité en français, du facile à l'avancé", url: "https://savoirs.rfi.fr/fr/apprendre-enseigner")
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
        .paperList()
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
            Text("\(score)").font(.number(16)).foregroundColor(Theme.scoreColor(score))
            LevelBadge(level: Level.cefr(score))
        }
    }
}

struct Bullet: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Theme.pen).frame(width: 5, height: 5).padding(.top, 7)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var speaker: Speaker
    @State private var confirmReset = false
    @State private var reminderTime = Date()
    @State private var denied = false

    var body: some View {
        Form {
            Section("Examen") {
                DatePicker("Date du TCF", selection: $progress.state.examDate, displayedComponents: .date)
                    .environment(\.locale, FR.locale)
            }
            Section {
                Toggle("Rappel quotidien", isOn: Binding(
                    get: { progress.state.reminderOn },
                    set: { on in setReminder(on) }
                ))
                if progress.state.reminderOn {
                    DatePicker("Heure", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .environment(\.locale, FR.locale)
                        .onChange(of: reminderTime) { t in
                            let c = Calendar.current.dateComponents([.hour, .minute], from: t)
                            progress.state.reminderHour = c.hour ?? 19
                            progress.state.reminderMinute = c.minute ?? 0
                            Reminders.schedule(hour: progress.state.reminderHour, minute: progress.state.reminderMinute)
                        }
                }
            } header: {
                Text("Rappel")
            } footer: {
                Text(denied ? "Les notifications sont refusées. Autorise-les dans Réglages iPhone › SansFaute." : "Une notification par jour pour ne pas casser ta série.")
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
                Text("Efface les résultats, les cartes, les erreurs et le temps enregistré. Tes propres mots et la date d'examen sont conservés.")
            }
            Section("À propos") {
                Text("SansFaute 1.1 · préparation TCF TP, du C1 vers le C2. Contenus originaux rédigés pour l'entraînement. Les scores affichés sont des estimations indicatives, pas des scores officiels.")
                    .font(.footnote).foregroundColor(Theme.muted)
            }
        }
        .paperList()
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            var c = DateComponents()
            c.hour = progress.state.reminderHour
            c.minute = progress.state.reminderMinute
            reminderTime = Calendar.current.date(from: c) ?? Date()
        }
        .confirmationDialog("Effacer toute la progression ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Effacer", role: .destructive) { progress.reset() }
            Button("Annuler", role: .cancel) {}
        }
    }

    private func setReminder(_ on: Bool) {
        if on {
            Reminders.requestAndSchedule(hour: progress.state.reminderHour, minute: progress.state.reminderMinute) { granted in
                progress.state.reminderOn = granted
                denied = !granted
            }
        } else {
            Reminders.cancel()
            progress.state.reminderOn = false
        }
    }
}
