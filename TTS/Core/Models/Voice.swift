//
//  Voice.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import Foundation

public enum VoiceGender: String {
    case male
    case female
    case unknown
}

struct Voice: Identifiable, Codable {
    let id = UUID()
    let name: String
    let language: String
    let accent: String
    let mood: String?
    let type: String
    let voiceSampleId: String
}

extension Voice {
    var gender: VoiceGender { voiceGender[self.voiceSampleId] ?? .unknown }
}

let voiceGender: [String: VoiceGender] = [

    // English (US)
    "com.apple.voice.super-compact.en-US.Samantha": .female,
    "com.apple.speech.synthesis.voice.Albert": .male,
    "com.apple.speech.synthesis.voice.BadNews": .male,
    "com.apple.speech.synthesis.voice.Bahh": .male,
    "com.apple.speech.synthesis.voice.Bells": .male,
    "com.apple.speech.synthesis.voice.Boing": .male,
    "com.apple.speech.synthesis.voice.Bubbles": .male,
    "com.apple.speech.synthesis.voice.Cellos": .male,
    "com.apple.speech.synthesis.voice.Deranged": .male,
    "com.apple.speech.synthesis.voice.Fred": .male,
    "com.apple.speech.synthesis.voice.GoodNews": .male,
    "com.apple.speech.synthesis.voice.Hysterical": .male,
    "com.apple.speech.synthesis.voice.Junior": .male,
    "com.apple.speech.synthesis.voice.Kathy": .female,
    "com.apple.speech.synthesis.voice.Organ": .male,
    "com.apple.speech.synthesis.voice.Princess": .female,
    "com.apple.speech.synthesis.voice.Ralph": .male,
    "com.apple.speech.synthesis.voice.Trinoids": .female,
    "com.apple.speech.synthesis.voice.Whisper": .male,
    "com.apple.speech.synthesis.voice.Zarvox": .male,

    // English (World)
    "com.apple.voice.super-compact.en-GB.Daniel": .male,
    "com.apple.voice.super-compact.en-AU.Karen": .female,
    "com.apple.voice.super-compact.en-IE.Moira": .female,
    "com.apple.voice.super-compact.en-IN.Rishi": .male,
    "com.apple.voice.super-compact.en-ZA.Tessa": .female,

    // European + International voices
    "com.apple.voice.super-compact.it-IT.Alice": .female,
    "com.apple.voice.super-compact.sv-SE.Alva": .female,
    "com.apple.voice.super-compact.fr-CA.Amelie": .female,
    "com.apple.voice.super-compact.ms-MY.Amira": .female,
    "com.apple.voice.super-compact.de-DE.Anna": .female,
    "com.apple.voice.super-compact.he-IL.Carmit": .female,
    "com.apple.voice.super-compact.id-ID.Damayanti": .female,
    "com.apple.voice.super-compact.bg-BG.Daria": .female,
    "com.apple.voice.super-compact.nl-BE.Ellen": .female,
    "com.apple.voice.super-compact.ro-RO.Ioana": .female,
    "com.apple.voice.super-compact.pt-PT.Joana": .female,
    "com.apple.voice.super-compact.th-TH.Kanya": .female,
    "com.apple.voice.super-compact.ja-JP.Kyoko": .female,
    "com.apple.voice.super-compact.hr-HR.Lana": .female,
    "com.apple.voice.super-compact.sk-SK.Laura": .female,
    "com.apple.voice.super-compact.hi-IN.Lekha": .female,
    "com.apple.voice.super-compact.uk-UA.Lesya": .female,
    "com.apple.voice.super-compact.vi-VN.Linh": .female,
    "com.apple.voice.super-compact.pt-BR.Luciana": .female,
    "com.apple.voice.super-compact.ar-001.Maged": .male,
    "com.apple.voice.super-compact.hu-HU.Mariska": .female,
    "com.apple.voice.super-compact.zh-TW.Meijia": .female,
    "com.apple.voice.super-compact.el-GR.Melina": .female,
    "com.apple.voice.super-compact.ru-RU.Milena": .female,
    "com.apple.voice.super-compact.es-ES.Monica": .female,
    "com.apple.voice.super-compact.ca-ES.Montserrat": .female,
    "com.apple.voice.super-compact.nb-NO.Nora": .female,
    "com.apple.voice.super-compact.es-MX.Paulina": .female,
    "com.apple.voice.super-compact.da-DK.Sara": .female,
    "com.apple.voice.super-compact.fi-FI.Satu": .female,
    "com.apple.voice.super-compact.zh-HK.Sinji": .female,
    "com.apple.voice.super-compact.fr-FR.Thomas": .male,
    "com.apple.voice.super-compact.sl-SI.Tina": .female,
    "com.apple.voice.super-compact.zh-CN.Tingting": .female,
    "com.apple.voice.super-compact.nl-NL.Xander": .male,
    "com.apple.voice.super-compact.tr-TR.Yelda": .female,
    "com.apple.voice.super-compact.ko-KR.Yuna": .female,
    "com.apple.voice.super-compact.pl-PL.Zosia": .female,
    "com.apple.voice.super-compact.cs-CZ.Zuzana": .female,

    // India regional
    "com.apple.voice.super-compact.ta-IN.Vani": .female,
    "com.apple.voice.compact.kn-IN.Alpana": .female,
    "com.apple.voice.compact.te-IN.Geeta": .female,
    "com.apple.voice.compact.bn-IN.Paya": .female
]
