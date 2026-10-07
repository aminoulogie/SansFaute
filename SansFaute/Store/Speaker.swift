import AVFoundation
import Foundation

/// Reads French text aloud with the device's French voices.
/// Two speakers in a dialogue get two different voices or pitches.
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()

    @Published private(set) var isSpeaking = false

    private let synth = AVSpeechSynthesizer()
    private var active: Set<ObjectIdentifier> = []

    override init() {
        super.init()
        synth.delegate = self
    }

    static var frenchVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("fr") }
    }

    /// True when only the basic compact voice is installed.
    static var hasEnhancedVoice: Bool {
        frenchVoices.contains { $0.quality != .default }
    }

    private func voices() -> (AVSpeechSynthesisVoice?, AVSpeechSynthesisVoice?) {
        let fr = Speaker.frenchVoices.filter { $0.language == "fr-FR" }
        let sorted = fr.sorted { $0.quality.rawValue > $1.quality.rawValue }
        let primary = sorted.first ?? AVSpeechSynthesisVoice(language: "fr-FR")
        let secondary = sorted.first { $0.identifier != primary?.identifier } ?? primary
        return (primary, secondary)
    }

    private func prepareSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    func speak(_ segments: [Segment], rate: Double) {
        stop()
        prepareSession()
        let (primary, secondary) = voices()
        let sameVoice = primary?.identifier == secondary?.identifier
        for s in segments {
            let u = AVSpeechUtterance(string: s.text)
            let isB = s.speaker == "B"
            u.voice = isB ? secondary : primary
            if sameVoice { u.pitchMultiplier = isB ? 1.25 : 0.9 }
            u.rate = Float(0.5 * rate) // 0.5 is the system default speaking rate
            u.postUtteranceDelay = 0.4
            active.insert(ObjectIdentifier(u))
            synth.speak(u)
        }
        isSpeaking = !active.isEmpty
    }

    func say(_ text: String, rate: Double) {
        speak([Segment(speaker: "A", text: text)], rate: rate)
    }

    func stop() {
        active.removeAll()
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        isSpeaking = false
    }

    private func finished(_ u: AVSpeechUtterance) {
        let id = ObjectIdentifier(u)
        DispatchQueue.main.async {
            self.active.remove(id)
            self.isSpeaking = !self.active.isEmpty
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finished(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finished(utterance)
    }
}
