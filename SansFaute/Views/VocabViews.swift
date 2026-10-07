import SwiftUI

struct VocabHomeView: View {
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    private var categories: [String] {
        var seen: [String] = []
        for c in content.vocab where !seen.contains(c.category) { seen.append(c.category) }
        return seen
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        stat(value: progress.dueCards(from: content.vocab).count, label: "à revoir")
                        Divider()
                        stat(value: progress.newCards(from: content.vocab).count, label: "nouvelles")
                        Divider()
                        stat(value: progress.knownCount(from: content.vocab), label: "acquises / \(content.vocab.count)")
                    }
                    .padding(.vertical, 6)
                    NavigationLink {
                        VocabSessionView()
                    } label: {
                        Label("Lancer la séance du jour", systemImage: "play.rectangle.on.rectangle")
                            .font(.headline)
                    }
                    Text("Cartes à répétition espacée : une carte sue revient dans 1, 2, 4, 7 puis 15 jours. Une carte ratée revient le jour même.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section("Parcourir") {
                    ForEach(categories, id: \.self) { cat in
                        NavigationLink {
                            VocabListView(category: cat)
                        } label: {
                            HStack {
                                Text(cat)
                                Spacer()
                                Text("\(content.vocab.filter { $0.category == cat }.count)")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Vocabulaire")
        }
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title2.weight(.bold).monospacedDigit()).foregroundColor(Theme.ink)
            Text(label).font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct VocabListView: View {
    let category: String
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var speaker: Speaker

    var body: some View {
        List(content.vocab.filter { $0.category == category }) { card in
            Button {
                speaker.say(card.term, rate: progress.state.speechRate)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(card.term).font(.headline).foregroundColor(.primary)
                        Spacer()
                        LevelBadge(level: card.level)
                    }
                    Text(card.definition).font(.subheadline).foregroundColor(.primary)
                    Text(card.example).font(.caption).italic().foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
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

    var body: some View {
        VStack(spacing: 20) {
            if let card = queue.first {
                HStack {
                    Text("\(reviewed) vues · \(queue.count) restantes")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(card.category).font(.caption).foregroundColor(.secondary)
                }
                cardView(card)
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { flipped.toggle() } }
                if flipped {
                    HStack(spacing: 12) {
                        Button {
                            grade(card, knew: false)
                        } label: {
                            Label("À revoir", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.pen)
                        Button {
                            grade(card, knew: true)
                        } label: {
                            Label("Je savais", systemImage: "checkmark")
                                .frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.good)
                    }
                } else {
                    Text("Touche la carte pour voir la définition")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if started {
                Spacer()
                Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundColor(Theme.good)
                Text("Séance terminée").font(.title2.weight(.bold))
                Text(reviewed > 0 ? "\(knewCount) cartes sues sur \(reviewed) vues." : "Aucune carte à revoir aujourd'hui. Reviens demain.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                ProgressView()
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Cartes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !started {
                let due = progress.dueCards(from: content.vocab)
                let fresh = progress.newCards(from: content.vocab)
                queue = due.shuffled() + fresh
                started = true
            }
        }
        .onDisappear { speaker.stop() }
    }

    private func cardView(_ card: VocabCard) -> some View {
        VStack(spacing: 14) {
            HStack {
                LevelBadge(level: card.level)
                Spacer()
                Button {
                    speaker.say(flipped ? card.example : card.term, rate: progress.state.speechRate)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
            }
            Spacer(minLength: 0)
            Text(card.term)
                .font(.system(.title, design: .serif).weight(.semibold))
                .multilineTextAlignment(.center)
            if flipped {
                Divider()
                Text(card.definition)
                    .font(.body)
                    .multilineTextAlignment(.center)
                Text(card.example)
                    .font(.callout)
                    .italic()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.ink.opacity(0.15), lineWidth: 1))
    }

    private func grade(_ card: VocabCard, knew: Bool) {
        progress.grade(card, knew: knew)
        reviewed += 1
        if knew { knewCount += 1 }
        withAnimation {
            queue.removeFirst()
            if !knew { queue.append(card) }
            flipped = false
        }
    }
}
