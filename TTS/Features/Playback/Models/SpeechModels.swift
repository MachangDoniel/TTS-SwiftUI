//
//  SpeechModels.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import Foundation

// MARK: - Request
struct SpeechGenerationRequest: Codable {
    let taskId: String
    let requestId: String?
    let inputText: String
    let order: Int
}

// MARK: - Response
struct SpeechGenerationData: Codable {
    let taskId: String?
    let requestId: String?
    let status: String?
    let progress: Int?
    let downloadUrl: String?
}

struct SpeechGenerationResponse: Codable {
    let status: String
    let message: String
    let data: SpeechGenerationData?
}
