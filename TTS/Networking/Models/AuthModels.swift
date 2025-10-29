//
//  AuthModels.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//


import Foundation

struct GoogleAuthRequest: Codable {
    let provider: String
    let idToken: String
    let platform: String
}

struct TokenData: Codable {
    let userId: String
    let accessToken: String
    let tokenType: String
    let accessExpiresInSeconds: Int
    let refreshToken: String
    let refreshExpiresInSeconds: Int
}

struct AuthResponse: Codable {
    let status: String
    let message: String
    let data: TokenData
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}
