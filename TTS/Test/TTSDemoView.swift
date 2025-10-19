//
//  TTSDemoView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import SwiftUI

struct TTSDemoView: View {
    @StateObject private var taskViewModel = TaskViewModel()
    @StateObject private var speechViewModel = SpeechViewModel()
    
    // For speech input
    @State private var inputText: String = "Hello, this is a test."
    @State private var order: Int = 1
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                
                // MARK: Create Task
                VStack(spacing: 15) {
                    Text("Step 1: Create Task")
                        .font(.headline)
                    
                    Button("Create Task") {
                        Task {
                            await taskViewModel.createTask(
                                title: "Test Task",
                                visitorId: "Test Visitor",
                                userId: nil,
                                voiceSampleId: "1",
                                platform: "IOS",
                                totalChunks: 1
                            )
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    if taskViewModel.isLoading {
                        ProgressView("Creating task...")
                    }
                    
                    if let taskId = taskViewModel.taskId {
                        Text("Task ID: \(taskId)")
                            .font(.footnote)
                    }
                    
                    if let error = taskViewModel.errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // MARK: Generate Speech
                VStack(spacing: 15) {
                    Text("Step 2: Generate Speech")
                        .font(.headline)
                    
                    TextField("Input Text", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Generate Speech") {
                        guard let taskId = taskViewModel.taskId else { return }
                        Task {
                            await speechViewModel.generateSpeech(
                                taskId: taskId,
                                requestId: nil,
                                inputText: inputText,
                                order: order
                            )
                        }
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    if speechViewModel.isLoading {
                        ProgressView("Generating speech...")
                    }
                    
                    if let data = speechViewModel.speechData {
                        Text("Status: \(data.status ?? "Unknown")")
                        Text("Progress: \(data.progress != nil ? "\(data.progress!)%" : "N/A")")
                        
                        if let downloadUrl = data.downloadUrl,
                           let url = URL(string: downloadUrl) {
                            Link("Download Audio", destination: url)
                                .foregroundColor(.blue)
                                .underline()
                        } else {
                            Text("Download URL: Not available")
                        }
                    }
                    
                    if let error = speechViewModel.errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // MARK: Check Status
                VStack(spacing: 15) {
                    Text("Step 3: Check Job Status")
                        .font(.headline)
                    
                    Button("Check Status") {
                        guard let taskId = taskViewModel.taskId,
                              let requestId = speechViewModel.speechData?.requestId else { return }
                        
                        Task {
                            await speechViewModel.checkStatus(
                                taskId: taskId,
                                requestId: requestId,
                                inputText: inputText,
                                order: order
                            )
                        }
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    if let data = speechViewModel.speechData {
                        Text("Status: \(data.status ?? "Unknown")")
                        Text("Progress: \(data.progress != nil ? "\(data.progress!)%" : "N/A")")
                        
                        if let downloadUrl = data.downloadUrl,
                           let url = URL(string: downloadUrl) {
                            Link("Download Audio", destination: url)
                                .foregroundColor(.blue)
                                .underline()
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
            }
            .padding()
        }
        .navigationTitle("TTS Demo")
    }
}

struct TTSDemoView_Previews: PreviewProvider {
    static var previews: some View {
        TTSDemoView()
    }
}
