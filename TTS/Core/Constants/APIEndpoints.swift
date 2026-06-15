//
//  APIEndpoints.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import Foundation
import Alamofire

struct APIEnvironment {
    let baseURL: String

    static let auth = APIEnvironment(baseURL: "https://api.theaudiothor.com")
    static let tts = APIEnvironment(baseURL: "http://68.183.127.122:8282")
}

struct AnyEncodable: Encodable {
    private let encodeImpl: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        self.encodeImpl = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeImpl(encoder)
    }
}

struct APIRequestDescriptor<Response: Decodable> {
    let environment: APIEnvironment
    let path: String
    let method: HTTPMethod
    let headers: HTTPHeaders
    let queryItems: [URLQueryItem]
    let body: AnyEncodable?
    let requiresAuth: Bool
    let timeout: TimeInterval

    init(
        environment: APIEnvironment,
        path: String,
        method: HTTPMethod = .get,
        headers: HTTPHeaders = [],
        queryItems: [URLQueryItem] = [],
        body: AnyEncodable? = nil,
        requiresAuth: Bool = false,
        timeout: TimeInterval = 60
    ) {
        self.environment = environment
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
        self.requiresAuth = requiresAuth
        self.timeout = timeout
    }
}

struct APIEnvelope<DataType: Decodable>: Decodable {
    let status: String
    let message: String
    let data: DataType
}

enum APIEndpoints {
    // MARK: - Auth
    static let googleAuth = "/api/tts/public/auth/google"
    static let logout = "/api/tts/public/auth/logout"
    static let refresh = "/api/tts/public/auth/refresh"

    // MARK: - Jobs
    static let uploadJobURL = "/api/tts/public/jobs/upload-url"
    static let speechGeneration = "/api/tts/public/speech-generation"

    // MARK: - Job Status
    static let jobStatus = "/api/tts/public/jobs/status"

    // MARK: - Voice Catalog
    static let publicVoices = "/api/tts/public/voices"
    static let publicLanguages = "/api/tts/public/languages"

    static func makeAuthRequest<T: Encodable, R: Decodable>(
        path: String,
        method: HTTPMethod = .post,
        body: T,
        headers: HTTPHeaders = [],
        requiresAuth: Bool = false
    ) -> APIRequestDescriptor<R> {
        APIRequestDescriptor(
            environment: .auth,
            path: path,
            method: method,
            headers: headers,
            body: AnyEncodable(body),
            requiresAuth: requiresAuth
        )
    }

    static func makeTTSRequest<T: Encodable, R: Decodable>(
        path: String,
        method: HTTPMethod = .post,
        body: T,
        headers: HTTPHeaders = [],
        requiresAuth: Bool = false
    ) -> APIRequestDescriptor<R> {
        APIRequestDescriptor(
            environment: .tts,
            path: path,
            method: method,
            headers: headers,
            body: AnyEncodable(body),
            requiresAuth: requiresAuth
        )
    }

    static func fetchPublicVoices() -> APIRequestDescriptor<APIEnvelope<[RemoteVoiceDTO]>> {
        APIRequestDescriptor(
            environment: .tts,
            path: publicVoices,
            method: .get,
            headers: ["Accept": "*/*"],
            requiresAuth: false
        )
    }

    static func fetchPublicLanguages() -> APIRequestDescriptor<APIEnvelope<[RemoteLanguageDTO]>> {
        APIRequestDescriptor(
            environment: .tts,
            path: publicLanguages,
            method: .get,
            headers: ["Accept": "*/*"],
            requiresAuth: false
        )
    }
}
