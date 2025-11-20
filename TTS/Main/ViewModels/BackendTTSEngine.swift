////
////  BackendTTSEngine.swift
////  TTS
////
////  Created by Doniel Tripura on 11/20/25.
////
//
//
//import Foundation
//import AVFAudio
//
//@MainActor
//final class BackendTTSEngine: NSObject, TTSEngine, AVAudioPlayerDelegate {
//    var sentences: [String] = []
//    var currentIndex: Int = 0
//    var state: TTSPlayerState = .idle
//    var progress: Double = 0.0
//    
//    private let backendWorker = TTSBackendService()
//    private var audioPlayer: AVAudioPlayer?
//    private var selectedVoiceSampleId: String = "1"
//    
//    func playCurrentSentence() {
//        guard sentences.indices.contains(currentIndex) else { return }
//        backendWorker.playSentence(
//            index: currentIndex,
//            sentences: sentences,
//            voiceId: selectedVoiceSampleId,
//            delegate: self
//        )
//        state = .playing
//    }
//    
//    func pause() { backendWorker.pause(); state = .paused }
//    func resume() { backendWorker.resume(); state = .playing }
//    func stop() { backendWorker.stopCurrent(); state = .idle }
//    
//    func nextSentence() { currentIndex += 1; playCurrentSentence() }
//    func previousSentence() { currentIndex -= 1; playCurrentSentence() }
//    
//    // MARK: - AVAudioPlayerDelegate
//    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
//        backendWorker.handleAudioFinished(player: self)
//    }
//}
