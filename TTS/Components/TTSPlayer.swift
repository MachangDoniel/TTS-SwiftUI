//
//  TTSPlayer.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//


import Foundation
import AVFoundation
import Combine

class TTSPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    
    @Published var sentences: [String] = []
    @Published var currentIndex: Int = 0
    @Published var isSpeaking: Bool = false
    @Published var isPaused: Bool = false
    
    private var synthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func startReading(_ text: String) {
        stop()
        sentences = splitIntoSentences(text)
        currentIndex = 0
        speakCurrentSentence()
    }
    
    // MARK: - Split text into sentences
    private func splitIntoSentences(_ text: String) -> [String] {
        let delimiters = CharacterSet(charactersIn: ".!?")
        let parts = text
            .components(separatedBy: delimiters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        print("📘 Total sentences: \(parts.count)")
        return parts
    }
    
    private func speakCurrentSentence() {
        guard sentences.indices.contains(currentIndex) else { return }
        let sentence = sentences[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
        isSpeaking = true
        isPaused = false
        print("🔊 Reading sentence \(currentIndex + 1)/\(sentences.count): \(sentence)")
    }
    
    func togglePlayPause() {
        if isSpeaking {
            if isPaused {
                synthesizer.continueSpeaking()
                isPaused = false
            } else {
                synthesizer.pauseSpeaking(at: .immediate)
                isPaused = true
            }
        } else {
            speakCurrentSentence()
        }
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
    }
    
    func nextSentence() {
        guard currentIndex < sentences.count - 1 else { return }
        stop()
        currentIndex += 1
        speakCurrentSentence()
    }
    
    func previousSentence() {
        guard currentIndex > 0 else { return }
        stop()
        currentIndex -= 1
        speakCurrentSentence()
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        isPaused = false
        if currentIndex < sentences.count - 1 {
            currentIndex += 1
            speakCurrentSentence()
        }
    }
}
