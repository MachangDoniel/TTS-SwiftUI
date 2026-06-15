//
//  BackendJobPhase.swift
//  TTS
//
//  Created by Assistant on 6/11/26.
//

import Foundation

enum BackendJobPhase: String, Codable {
    case idle
    case requestingUploadURL
    case uploadingSource
    case triggeringSpeechGeneration
    case inQueue
    case inProgress
    case prefetchingNextChunk
    case completed
    case failed

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .requestingUploadURL: return "Preparing Upload"
        case .uploadingSource: return "Uploading"
        case .triggeringSpeechGeneration: return "Starting TTS"
        case .inQueue: return "In Queue"
        case .inProgress: return "In Progress"
        case .prefetchingNextChunk: return "Prefetching Next"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    static func fromRemoteStatus(_ status: String?) -> BackendJobPhase {
        guard let normalized = status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return .idle
        }

        switch normalized {
        case "in queue", "in_queue":
            return .inQueue
        case "in progress", "in_progress":
            return .inProgress
        case "completed":
            return .completed
        case "failed", "error":
            return .failed
        default:
            return .idle
        }
    }
}
