//
//  BackendAccessTier.swift
//  TTS
//
//  Created by Assistant on 6/11/26.
//

import Foundation

enum BackendAccessTier: String, Codable, CaseIterable {
    case free = "Free"
    case premium = "Premium"

    var prefetchDistance: Int {
        switch self {
        case .free:
            return 1
        case .premium:
            return 2
        }
    }
}
