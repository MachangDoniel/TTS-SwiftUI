//
//  CreateTaskRequest.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//


import Foundation

struct CreateTaskRequest: Codable {
    let title: String
    let visitorId: String?
    let userId: String?
    let voiceSampleId: String?
    let platform: String?
    let totalChunks: Int
}

struct TaskData: Codable {
    let taskId: String
}

struct CreateTaskResponse: Codable {
    let status: String
    let message: String
    let data: TaskData
}
