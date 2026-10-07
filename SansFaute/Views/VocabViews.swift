import SwiftUI

struct VocabHomeView: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    @State private var search = ""
    @State private var showAdd = false

    private var all: [VocabCard] { progress.allCards(content) }

    private var categories: [String] {
        var seen: [String] = []
        for c in content.vocab where !seen.contains(c.category) { seen.append(c.category) }
        return seen
    }

    private var results: [VocabCard] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return all.filter { $0.term.lowercased().contains(q) || $0.definition.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !search.isEmpty {
                        VStack(spacing: 10) {
                            if results.isEmpty {
                                Text("Aucun mot trouvé pour « \(search) ».").foregroundColor(Theme.muted).card()
                            }
                            ForEach(results) { card in WordCardRow(card: card) }
                        }
                    } else {
                        overview
                        SectionHeader(eyebrow: "Ta liste", title: "Mes mots et favoris")
                        VStack(spacing: 10) {
                            NavigationLink {
                                VocabListView(title: "Mes mots", cards: progress.state.customCards, allowDelete: true)
                            } label: {
                                RowCard(symbol: "square.and.pencil", title: "Mes mots",
                                        subtitle: "Les mots entendus à la radio ou lus dans la presse",
                                        color: Theme.good, trailing: "\(progress.state.customCards.count)")
                            }
                            NavigationLink {
                                VocabListView(title: "Favoris", cards: all.filter { progress.isFavorite($0) }, allowDelete: false)
                            } label: {
                                RowCard(symbol: "star.fill", title: "Favoris", subtitle: "Les cartes marquées d'une étoile",
                                        color: Theme.warn, trailing: "\(progress.state.favorites.count)")
                            }
                        }
                        .buttonStyle(PressableStyle())

                        SectionHeader(eyebrow: "\(content.vocab.count) cartes C1 · C2", title: "Par thème")
                        VStack(spacing: 10) {
                            ForEach(categories, id: \.self) { cat in
                                let cards = content.vocab.filter { $0.category == cat }
                                let known = cards.filter { progress.box(of: $0) >= 3 }.count
                                NavigationLink {
                                    VocabListView(title: cat, cards: cards, allowDelete: false)
                                } label: {
                                    RowCard(symbol: symbol(for: cat), title: cat, subtitle: "\(known) acquises sur \(cards.count)",
                                            color: Theme.ink, trailing: nil)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .paperBackground()
            .navigationTitle("Vocabulaire")
            .searchable(text: $search, prompt: "Chercher un mot")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus.circle.fill") }
                }
            }
            .sheet(isPresented: $showAdd) { AddWordView() }
        }
    }

    private var overview: some View {
        let due = progress.dueCards(from: all).count
        let fresh = progress.newCards(from: all).count
        let known = progress.knownCount(from: all)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 0) {
                stat(due, "à revoir", Theme.pen)
                Divider().frame(height: 40)
                stat(fresh, "nouvelles", Theme.ink)
                Divider().frame(height: 40)
                stat(known, "acquises", Theme.good)
            }
            ProgressView(value: Double(known), total: Double(max(1, all.count)))
                .tint(Theme.good)
            Text("\(known) cartes acquises sur \(all.count). Une carte sue revient dans 1, 2, 4, 7 puis 15 jours ; une carte ratée revient tout de suite.")
                .font(.caption).foregroundColor(Theme.muted)
            NavigationLink {
                VocabSessionView()
            } label: {
                Label(due + fresh > 0 ? "Séance du jour · \(due + fresh) cartes" : "Rien à revoir, reviens demain",
                      systemImage: "rectangle.stack.fill")
            }
            .buttonStyle(InkButtonStyle())
            .disabled(due + fresh == 0)
        }
        .card(padding: 18)
        .padding(.top, 6)
    }

    private func stat(_ value: Int, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.number(28)).foregroundColor(color)
            Text(label).font(.caption).foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func symbol(for category: String) -> String {
        switch category {
        case "Connecteurs": return "link"
        case "Verbes soutenus": return "text.quote"
        case "Expressions": return "quote.bubble"
        case "Académique": return "graduationcap"
        case "Attitude": return "theatermasks"
        case "Génie civil": return "building.2"
        case "Presse et société": return "newspaper"
        case "Paronymes": return "arrow.left.arrow.right"
        default: return "character.book.closed"
        }
    }
}

struct WordCardRow: View {
    let card: VocabCard
    var allowDelete = false
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var speaker: Speaker

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.term).font(.serif(.headline, weight: .bold)).foregroundColor(Theme.ink)
                Spacer()
                Button {
                    speaker.say(card.term + ". " + card.example, rate: progress.state.speechRate)
                } label: { Image(systemName: "speaker.wave.2") }
                Button {
                    Haptics.tap()
                    progress.toggleFavorite(card)
                } label: {
                    Image(systemName: progress.isFavorite(card) ? "star.fill" : "star")
                        .foregroundColor(progress.isFavorite(card) ? Theme.warn : Theme.muted)
                }
                if allowDelete {
                    Button {
                        progress.deleteCustomCard(card)
                    } label: { Image(systemName: "trash").foregroundColor(Theme.pen) }
                }
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            Text(card.definition).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            if !card.example.isEmpty {
                Text(card.example).font(.system(.footnote, design: .serif)).italic().foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule().fill(i < max(0, progress.box(of: card)) ? Theme.good : Theme.inkSoft).frame(height: 3)
                }
            }
            .frame(maxWidth: 90)
        }
        .card(padding: 14)
    }
}

struct VocabListView: View {
    let title: String
    let cards: [VocabCard]
    let allowDelete: Bool
    @EnvironmentObject private var progress: ProgressStore

    private var live: [VocabCard] {
        allowDelete ? progress.state.customCards : cards
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if live.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray").font(.largeTitle).foregroundColor(Theme.muted)
                        Text(allowDelete ? "Ajoute tes propres mots avec le bouton + de l'onglet Mots." : "Aucune carte ici pour l'instant.")
                            .multilineTextAlignment(.center).foregroundColor(Theme.muted)
                    }
                    .padding(.top, 60)
                }
                ForEach(live) { card in WordCardRow(card: card, allowDelete: allowDelete) }
            }
            .padding(20)
        }
        .paperBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AddWordView: View {
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var definition = ""
    @State private var example = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Le mot ou l'expression", text: $term)
                        .autocorrectionDisabled()
                    TextField("Sa définition", text: $definition, axis: .vertical)
                    TextField("Une phrase d'exemple (facultatif)", text: $example, axis: .vertical)
                } footer: {
                    Text("Tes mots passent en premier dans les nouvelles cartes de la séance.")
                }
            }
            .paperList()
            .navigationTitle("Nouveau mot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        progress.addCustomCard(term: term.trimmingCharacters(in: .whitespaces),
                                               definition: definition.trimmingCharacters(in: .whitespaces),
                                               example: example.trimmingCharacters(in: .whitespaces))
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty || definition.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct VocabSessionView: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var speaker: Speaker

    @State private var queue: [VocabCard] = []
    @State private var started = false
    @State private var flipped = false
    @State private var reviewed = 0
    @State private var knewCount = 0
    @State private var startedAt = Date()
    @State private var drag: CGSize = .zero

    var body: some View {
        VStack(spacing: 18) {
            if let card = queue.first {
                HStack {
                    Text("\(reviewed) vues").font(.caption.monospacedDigit()).foregroundColor(Theme.muted)
                    Spacer()
                    Text("\(queue.count) restantes").font(.caption.monospacedDigit()).foregroundColor(Theme.muted)
                }
                ProgressView(value: Double(reviewed), total: Double(reviewed + queue.count)).tint(Theme.ink)

                cardView(card)
                    .offset(x: drag.width)
                    .rotationEffect(.degrees(Double(drag.width) / 25))
                    .gesture(
                        DragGesture()
                            .onChanged { v in if flipped { drag = v.translation } }
                            .onEnded { v in
                                if flipped && abs(v.translation.width) > 110 {
                                    grade(card, knew: v.translation.width > 0)
                                }
                                withAnimation(.spring()) { drag = .zero }
                            }
                    )
                    .onTapGesture { withAnimation(.spring(response: 0.35)) { flipped.toggle() } }

                if flipped {
                    HStack(spacing: 12) {
                        Button { grade(card, knew: false) } label: {
                            Label("À revoir", systemImage: "arrow.uturn.left")
                        }
                        .buttonStyle(InkButtonStyle(color: Theme.pen))
                        Button { grade(card, knew: true) } label: {
                            Label("Je savais", systemImage: "checkmark")
                        }
                        .buttonStyle(InkButtonStyle(color: Theme.good))
                    }
                    Text("Ou glisse la carte : à droite si tu savais, à gauche sinon.")
                        .font(.caption2).foregroundColor(Theme.muted)
                } else {
                    Text("Essaie de donner le sens, puis touche la carte.")
                        .font(.footnote).foregroundColor(Theme.muted)
                }
                Spacer(minLength: 0)
            } else if started {
                Spacer()
                Image(systemName: "checkmark.seal.fill").font(.system(size: 60)).foregroundColor(Theme.good)
                Text("Séance terminée").font(.serif(.title, weight: .bold))
                Text(reviewed > 0 ? "\(knewCount) cartes sues sur \(reviewed) vues." : "Aucune carte à revoir aujourd'hui. Reviens demain.")
                    .foregroundColor(Theme.muted).multilineTextAlignment(.center)
                Spacer()
            } else {
                ProgressView()
            }
        }
        .padding(20)
        .paperBackground()
        .navigationTitle("Cartes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !started {
                let all = progress.allCards(content)
                queue = progress.dueCards(from: all).shuffled() + progress.newCards(from: all)
                started = true
                startedAt = Date()
            }
        }
        .onDisappear {
            speaker.stop()
            progress.addStudy(seconds: Int(Date().timeIntervalSince(startedAt)))
        }
    }

    private func cardView(_ card: VocabCard) -> some View {
        VStack(spacing: 16) {
            HStack {
                LevelBadge(level: card.level)
                Text(card.category).font(.caption).foregroundColor(Theme.muted)
                Spacer()
                Button {
                    Haptics.tap()
                    progress.toggleFavorite(card)
                } label: {
                    Image(systemName: progress.isFavorite(card) ? "star.fill" : "star")
                        .foregroundColor(progress.isFavorite(card) ? Theme.warn : Theme.muted)
                }
                Button {
                    speaker.say(flipped ? card.example : card.term, rate: progress.state.speechRate)
                } label: {
                    Image(systemName: "speaker.wave.2.fill").foregroundColor(Theme.ink)
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            Text(card.term)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
            if flipped {
                Rectangle().fill(Theme.margin).frame(width: 60, height: 1.5)
                Text(card.definition)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if !card.example.isEmpty {
                    Text(card.example)
                        .font(.system(.callout, design: .serif))
                        .italic()
                        .foregroundColor(Theme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 340)
        .background(
            ZStack {
                Theme.card
                if drag.width > 30 { Theme.good.opacity(min(0.25, Double(drag.width) / 600)) }
                if drag.width < -30 { Theme.pen.opacity(min(0.25, Double(-drag.width) / 600)) }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
    }

    private func grade(_ card: VocabCard, knew: Bool) {
        progress.grade(card, knew: knew)
        knew ? Haptics.success() : Haptics.tap()
        reviewed += 1
        if knew { knewCount += 1 }
        withAnimation(.spring(response: 0.35)) {
            if !queue.isEmpty { queue.removeFirst() }
            if !knew { queue.append(card) }
            flipped = false
            drag = .zero
        }
    }
}
