//
//  SpeechViewModel.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//


//
//  SpeechViewModel.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import Foundation
import Combine

@MainActor
final class SpeechViewModel: ObservableObject {
    @Published var speechData: SpeechGenerationData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func generateSpeech(taskId: String, requestId: String?, inputText: String, order: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        let body = SpeechGenerationRequest(
            taskId: taskId,
            requestId: requestId,
            inputText: inputText,
            order: order
        )
        
        do {
            let request: APIRequestDescriptor<SpeechGenerationResponse> = APIEndpoints.makeTTSRequest(
                path: APIEndpoints.speechGeneration,
                body: body
            )
            let response = try await APIClient.shared.send(request)
            speechData = response.data
            
            if let url = response.data?.downloadUrl {
                Logger.log("✅ Download URL: \(url)")
            } else {
                Logger.log("ℹ️ Speech generation in progress, URL not ready yet.")
            }
        } catch {
            errorMessage = error.localizedDescription
            Logger.log("❌ Failed to generate speech: \(error.localizedDescription)")
        }
    }
    
    func checkStatus(
        taskId: String,
        requestId: String,
        inputText: String,
        order: Int
    ) async {
        isLoading = true
        defer { isLoading = false }
        
        let body = SpeechGenerationRequest(
            taskId: taskId,
            requestId: requestId,
            inputText: inputText,
            order: order
        )
        
        do {
            let request: APIRequestDescriptor<SpeechGenerationResponse> = APIEndpoints.makeTTSRequest(
                path: APIEndpoints.jobStatus,
                body: body
            )
            let response = try await APIClient.shared.send(request)
            speechData = response.data
            
            // ✅ Safely unwrap optional data
            if let data = response.data {
                let status = data.status ?? "Unknown"
                let progressText = data.progress != nil ? "\(data.progress!)%" : "N/A"
                
                Logger.log("✅ Job Status: \(status), Progress: \(progressText)")
            } else {
                Logger.log("⚠️ No job data returned")
            }
            
        } catch {
            errorMessage = error.localizedDescription
            Logger.log("❌ Failed to fetch job status: \(error.localizedDescription)")
        }
    }
}
