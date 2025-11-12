//
//  APIEndpoints.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//


import Foundation

struct APIEndpoints {
    static let baseURL = "https://api.theaudiothor.com"

    // MARK: - Auth
    static let googleAuth = "/api/tts/public/auth/google"
    static let logout = "/api/tts/public/auth/logout"
    static let refresh = "/api/tts/public/auth/refresh"
        
    // MARK: - Task
//    static let createTask = "/api/tts/app/task/create"
    static let createTask = "/api/tts/public/task/create"
        
    // MARK: - Speech
//    static let speechGeneration = "/api/tts/app/speech-generation"
    static let speechGeneration = "/api/tts/public/speech-generation"
    
    // MARK: - Job Status
    static let jobStatus = "/api/tts/public/jobs/status"
    
}
