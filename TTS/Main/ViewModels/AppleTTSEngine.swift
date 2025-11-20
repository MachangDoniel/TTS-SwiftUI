////
////  AppleTTSEngine.swift
////  TTS
////
////  Created by Doniel Tripura on 11/20/25.
////
//
//
//import Foundation
//import AVFoundation
//
//@MainActor
//final class AppleTTSEngine: NSObject, TTSEngine {
//    var sentences: [String] = []
//    var currentIndex: Int = 0
//    var state: TTSPlayerState = .idle
//    var progress: Double = 0.0
//    
//    private let config: TTSConfiguration
//    private var synthesizer: AVSpeechSynthesizer
//    private var selectedVoiceSampleId: String = "1"
//    
//    init(config: TTSConfiguration) {
//        self.config = config
//        self.synthesizer = AVSpeechSynthesizer()
//        super.init()
//        self.synthesizer.delegate = self
//    }
//    
//    func playCurrentSentence() {
//        guard sentences.indices.contains(currentIndex) else { return }
//        let sentence = sentences[currentIndex]
//        let utterance = AVSpeechUtterance(string: sentence)
//        if let sysVoice = AVSpeechSynthesisVoice(identifier: selectedVoiceSampleId) {
//            utterance.voice = sysVoice
//        } else {
//            utterance.voice = AVSpeechSynthesisVoice(language: config.language)
//        }
//        utterance.rate = config.rate
//        synthesizer.speak(utterance)
//        state = .playing
//    }
//    
//    func pause() { synthesizer.pauseSpeaking(at: .immediate); state = .paused }
//    func resume() { synthesizer.continueSpeaking(); state = .playing }
//    func stop() { synthesizer.stopSpeaking(at: .immediate); state = .idle }
//    
//    func nextSentence() { currentIndex += 1; playCurrentSentence() }
//    func previousSentence() { currentIndex -= 1; playCurrentSentence() }
//}
//
//extension AppleTTSEngine: AVSpeechSynthesizerDelegate {
//    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
//                           didFinish utterance: AVSpeechUtterance) {
//        currentIndex += 1
//        if currentIndex < sentences.count {
//            playCurrentSentence()
//        } else {
//            state = .finished
//        }
//    }
//}
