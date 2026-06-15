//
//  SpeechModels.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import Foundation

struct UploadJobURLRequest: Codable {
    let userId: String?
    let visitorId: String?
    let characterCount: Int
    let voiceSampleId: Int
    let languageCode: String
    let platform: String
    let scanner: Bool
    let fileExtension: String
}

struct UploadJobURLData: Codable {
    let requestId: String
    let uploadUrl: String
}

struct UploadJobURLResponse: Codable {
    let status: String
    let message: String
    let data: UploadJobURLData
}

struct JobStatusRequest: Codable {
    let requestId: String
    let userId: String?
    let visitorId: String?
}

struct JobStatusData: Codable {
    let requestId: String
    let status: String
    let progress: Int?
    let downloadUrl: String?
    let chunkTextUrls: [String]?
}

struct JobStatusResponse: Codable {
    let status: String
    let message: String
    let data: JobStatusData
}

struct DownloadedChunkText: Identifiable, Equatable {
    let index: Int
    let sourceURL: String
    let text: String

    var id: Int { index }
}
