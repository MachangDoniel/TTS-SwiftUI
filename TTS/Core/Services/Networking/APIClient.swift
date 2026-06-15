//
//  APIClient.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import Foundation
import Alamofire

// MARK: - Weak AuthViewModel singleton for APIClient integration
private weak var globalAuthVM: AuthViewModel? = nil

func setGlobalAuthViewModel(_ vm: AuthViewModel) {
    globalAuthVM = vm
    APIClient.shared.interceptor = ApiInterceptor(authVM: vm)
}

final class APIClient {
    static let shared = APIClient()

    var interceptor: ApiInterceptor?

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        self.encoder = encoder
        self.decoder = decoder
    }

    func request<T: Encodable, R: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .post,
        body: T,
        headers: HTTPHeaders? = nil,
        requiresAuth: Bool = false
    ) async throws -> R {
        let descriptor: APIRequestDescriptor<R> = APIEndpoints.makeAuthRequest(
            path: endpoint,
            method: method,
            body: body,
            headers: headers ?? [],
            requiresAuth: requiresAuth
        )
        return try await send(descriptor)
    }

    func send<R: Decodable>(_ descriptor: APIRequestDescriptor<R>) async throws -> R {
        let request = try makeURLRequest(from: descriptor)

        logRequest(request)

        let afResponse = await AF.request(
            request,
            interceptor: descriptor.requiresAuth ? interceptor : nil
        )
        .serializingData()
        .response

        let statusCode = afResponse.response?.statusCode ?? -1
        logResponse(url: request.url?.absoluteString ?? "unknown", statusCode: statusCode, data: afResponse.data)

        switch afResponse.result {
        case .success(let data):
            guard !data.isEmpty else { throw APIError.emptyResponse }
            guard (200...299).contains(statusCode) else {
                if statusCode == 401 {
                    throw APIError.unauthorized
                }
                throw APIError.server(statusCode)
            }

            do {
                return try decoder.decode(R.self, from: data)
            } catch {
                Logger.apiError("JSON decoding failed: \(error.localizedDescription)")
                throw APIError.decoding(error)
            }

        case .failure(let error):
            if let responseCode = afResponse.response?.statusCode {
                if responseCode == 401 {
                    throw APIError.unauthorized
                }
                throw APIError.server(responseCode)
            }
            throw APIError.network(error)
        }
    }

    private func makeURLRequest<R>(from descriptor: APIRequestDescriptor<R>) throws -> URLRequest {
        let rawURL = descriptor.environment.baseURL + descriptor.path
        guard var components = URLComponents(string: rawURL) else {
            throw APIError.invalidURL(rawURL)
        }

        if !descriptor.queryItems.isEmpty {
            components.queryItems = descriptor.queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL(rawURL)
        }

        var request = URLRequest(url: url, timeoutInterval: descriptor.timeout)
        request.httpMethod = descriptor.method.rawValue

        var headers = descriptor.headers
        if descriptor.body != nil {
            headers.add(.contentType("application/json"))
        }

        for header in headers {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        if let body = descriptor.body {
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    private func logRequest(_ request: URLRequest) {
        Logger.apiRequest(request)
    }

    private func logResponse(url: String, statusCode: Int, data: Data?) {
        Logger.apiResponse(url: url, statusCode: statusCode, data: data)
    }
}
