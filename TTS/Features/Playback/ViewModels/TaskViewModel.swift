//
//  TaskViewModel.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//


import Foundation
import Combine

@MainActor
final class TaskViewModel: ObservableObject {
    @Published var taskId: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func createTask(
        title: String,
        visitorId: String?,
        userId: String?,
        voiceSampleId: String?,
        platform: String?,
        totalChunks: Int
    ) async {
        isLoading = true
        defer { isLoading = false }
        
        let body = CreateTaskRequest(
            title: title,
            visitorId: visitorId,
            userId: userId,
            voiceSampleId: voiceSampleId,
            platform: platform,
            totalChunks: totalChunks
        )
        
        do {
            let response: CreateTaskResponse = try await APIClient.shared.request(
                APIEndpoints.createTask,
                body: body
            )
            taskId = response.data.taskId
            Logger.log("✅ Task created: \(response.data.taskId)")
        } catch {
            errorMessage = error.localizedDescription
            Logger.log("❌ Failed to create task: \(error.localizedDescription)")
        }
    }
}
