import SwiftUI

/// Walks through today's plan one block at a time, with a timer for each block.
struct GuidedSessionView: View {
    let day: PlanDay

    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var progress: ProgressStore

    @State private var step = 0
    @State private var running = false
    @State private var startedAt: Date? = nil
    @State private var accumulated: TimeInterval = 0
    @State private var finished = false

    private var steps: [(index: Int, task: PlanTask)] {
        day.tasks.enumerated().filter { $0.element.minutes > 0 }.map { (index: $0.offset, task: $0.element) }
    }

    private var tips: [PlanTask] { day.tasks.filter { $0.minutes == 0 } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if finished || steps.isEmpty {
                    doneView
                } else {
                    stepper
                    current
                    if !tips.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "En plus aujourd'hui")
                            ForEach(tips, id: \.label) { t in
                                Label(t.label, systemImage: TaskDestination.symbol(for: t))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                        .card()
                    }
                }
            }
            .padding(20)
        }
        .paperBackground()
        .overlay { if finished { Confetti() } }
        .navigationTitle("Séance du jour \(day.day)")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { pause() }
    }

    private var stepper: some View {
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { i in
                Capsule()
                    .fill(i < step ? Theme.good : (i == step ? Theme.ink : Theme.inkSoft))
                    .frame(height: 6)
            }
        }
    }

    private var current: some View {
        let s = steps[min(step, steps.count - 1)]
        let total = TimeInterval(s.task.minutes * 60)
        return VStack(spacing: 18) {
            VStack(spacing: 4) {
                Eyebrow(text: "Étape \(step + 1) sur \(steps.count)")
                Text(s.task.label)
                    .font(.serif(.title2))
                    .multilineTextAlignment(.center)
                if let d = TaskDestination.detail(for: s.task, content: content) {
                    Text(d).font(.subheadline).foregroundColor(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity)

            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let elapsed = accumulated + (running ? ctx.date.timeIntervalSince(startedAt ?? ctx.date) : 0)
                let remaining = max(0, total - elapsed)
                ZStack {
                    ProgressRing(progress: min(1, elapsed / max(1, total)), lineWidth: 14,
                                 color: remaining == 0 ? Theme.good : Theme.ink)
                    VStack(spacing: 2) {
                        Text(String(format: "%d:%02d", Int(remaining) / 60, Int(remaining) % 60))
                            .font(.number(44))
                            .foregroundColor(remaining == 0 ? Theme.good : .primary)
                        Text(remaining == 0 ? "temps écoulé" : (running ? "en cours" : "en pause"))
                            .font(.caption).foregroundColor(Theme.muted)
                    }
                }
                .frame(width: 200, height: 200)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Button {
                    running ? pause() : resume()
                } label: {
                    Label(running ? "Pause" : (accumulated > 0 ? "Reprendre" : "Lancer le chrono"),
                          systemImage: running ? "pause.fill" : "play.fill")
                }
                .buttonStyle(SoftButtonStyle())
                if TaskDestination.exists(for: s.task) {
                    NavigationLink {
                        TaskDestination(task: s.task)
                            .onAppear { if !running { resume() } }
                    } label: {
                        Label("Ouvrir", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(SoftButtonStyle(color: Theme.violet))
                }
            }

            Button {
                completeStep(index: s.index)
            } label: {
                Label(step + 1 == steps.count ? "Terminer la séance" : "Étape terminée", systemImage: "checkmark")
            }
            .buttonStyle(InkButtonStyle(color: Theme.good))
        }
        .card(padding: 20)
    }

    private var doneView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundColor(Theme.good)
            Text("Séance terminée").font(.serif(.largeTitle, weight: .bold))
            Text("\(progress.minutes(on: Date())) minutes de travail aujourd'hui. Série : \(progress.streak) jour\(progress.streak > 1 ? "s" : "").")
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
            Text("Demain, même heure. La régularité compte plus que l'intensité.")
                .font(.footnote).foregroundColor(Theme.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 24)
        .padding(.top, 40)
    }

    // MARK: - Timer

    private func resume() {
        startedAt = Date()
        running = true
    }

    private func pause() {
        if running, let s = startedAt { accumulated += Date().timeIntervalSince(s) }
        running = false
        startedAt = nil
    }

    private func completeStep(index: Int) {
        pause()
        progress.addStudy(seconds: Int(accumulated))
        progress.setDone(day: day.date, index: index)
        Haptics.success()
        accumulated = 0
        if step + 1 < steps.count {
            withAnimation { step += 1 }
        } else {
            withAnimation { finished = true }
        }
    }
}
