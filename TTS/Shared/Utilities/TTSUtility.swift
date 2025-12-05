//
//  TTSUtility.swift
//  TTS
//
//  Created by Doniel Tripura on 12/1/25.
//

import Foundation

public struct TTSUtility {
    public static func determineFileType(from url: URL) -> FileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return .pdf
        case "png", "jpg", "jpeg", "heic":
            return .image
        default:
            return .text
        }
    }
    
    public static func isTextFile(url: URL) -> Bool {
        return determineFileType(from: url) == .text
    }
    
    public static func findGender() -> VoiceGender {
        if let savedVoiceId = UserDefaults.standard.string(forKey: KeyString.selectedVoiceSampleId) {
            return voiceGender[savedVoiceId] ?? .unknown
        }
        return .unknown
    }
    
    public static func getVoiceImage() -> String? {
        switch findGender() {
        case .male:
            return ImageAssets.male_voice
        case .female:
            return ImageAssets.female_voice
        default:
            return ImageAssets.robot_voice
        }
    }
}
