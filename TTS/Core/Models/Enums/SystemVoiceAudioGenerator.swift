//
//  SystemVoiceAudioGenerator.swift
//  TTS
//
//  Created by Assistant on 11/23/25.
//

import Foundation
import AVFoundation
import Combine

@MainActor
class SystemVoiceAudioGenerator: NSObject {
    private var synthesizer = AVSpeechSynthesizer()
    private var outputURL: URL?
    private var continuation: CheckedContinuation<URL, Error>?
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    /// Generate audio file from text using system voice
    func generateAudioFile(
        text: String,
        voiceId: String,
        outputURL: URL,
        rate: Float = 0.5,
        pitch: Float = 1.0,
        volume: Float = 1.0
    ) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.outputURL = outputURL
            
            // Setup audio session for file output
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .default)
                try audioSession.setActive(true)
            } catch {
                continuation.resume(throwing: error)
                return
            }
            
            // Create utterance
            let utterance = AVSpeechUtterance(string: text)
            
            // Configure voice
            if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
                utterance.voice = voice
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            }
            
            utterance.rate = rate
            utterance.pitchMultiplier = pitch
            utterance.volume = volume
            
            // Start recording to file
            startRecording()
            
            // Speak the utterance
            synthesizer.speak(utterance)
        }
    }
    
    private func startRecording() {
        guard let outputURL = outputURL else { return }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            let audioRecorder = try AVAudioRecorder(url: outputURL, settings: settings)
            audioRecorder.record()
            
            // Store recorder reference to keep it alive
            objc_setAssociatedObject(self, "audioRecorder", audioRecorder, .OBJC_ASSOCIATION_RETAIN)
        } catch {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
    
    private func stopRecording() {
        if let recorder = objc_getAssociatedObject(self, "audioRecorder") as? AVAudioRecorder {
            recorder.stop()
            objc_setAssociatedObject(self, "audioRecorder", nil, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

extension SystemVoiceAudioGenerator: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        // Speech started
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            stopRecording()
            
            if let outputURL = outputURL {
                continuation?.resume(returning: outputURL)
            } else {
                continuation?.resume(throwing: SystemVoiceError.noOutputURL)
            }
            
            continuation = nil
            self.outputURL = nil
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            stopRecording()
            continuation?.resume(throwing: SystemVoiceError.cancelled)
            continuation = nil
            outputURL = nil
        }
    }
}

enum SystemVoiceError: LocalizedError {
    case noOutputURL
    case cancelled
    case recordingFailed
    
    var errorDescription: String? {
        switch self {
        case .noOutputURL:
            return "No output URL specified"
        case .cancelled:
            return "Speech synthesis was cancelled"
        case .recordingFailed:
            return "Failed to start audio recording"
        }
    }
}