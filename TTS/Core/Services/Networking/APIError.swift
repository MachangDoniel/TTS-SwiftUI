//
//  APIError.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import Foundation

enum APIError: Error, LocalizedError, Equatable {
    case network(Error)          // Underlying network error
    case server(Int)             // HTTP status code
    case decoding(Error)         // JSON decoding failure
    case unauthorized            // 401
    case unknown                 // Fallback

    var errorDescription: String? {
        switch self {
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .server(let code):
            return "Server error with status code: \(code)"
        case .decoding(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unauthorized:
            return "Session expired. Please log in again."
        case .unknown:
            return "An unknown error occurred."
        }
    }

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.server(let l), .server(let r)): return l == r
        case (.unauthorized, .unauthorized): return true
        case (.unknown, .unknown): return true
        case (.network, .network), (.decoding, .decoding): return false // Cannot easily compare generic Errors
        default: return false
        }
    }
}
