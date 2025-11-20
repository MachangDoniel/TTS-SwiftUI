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
    APIClient.shared.interceptor = AuthInterceptor(authVM: vm)
}

final class APIClient {
    static let shared = APIClient()
    
    // The interceptor is updated when setGlobalAuthViewModel is called
    var interceptor: AuthInterceptor?
    
    private init() {}
    
    func request<T: Encodable, R: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .post,
        body: T,
        headers: HTTPHeaders? = nil
    ) async throws -> R {
        
        let url = APIEndpoints.baseURL + endpoint
        
        // MARK: Log Request
        // We can log here, but the interceptor also sees the request. 
        // However, for consistency with previous behavior, we'll log the body.
        if let requestData = try? JSONEncoder().encode(body),
           let jsonString = String(data: requestData, encoding: .utf8) {
            Logger.debugPrint("➡️ REQUEST → \(method.rawValue) \(url)")
            Logger.debugPrint("📦 Body:")
            print(jsonString)
        }
        
        // MARK: Send Request with Interceptor
        // The interceptor handles Authorization header injection and 401 retries.
        let afResponse = await AF.request(
            url,
            method: method,
            parameters: body,
            encoder: JSONParameterEncoder.default,
            headers: headers,
            interceptor: interceptor
        )
        .serializingData()
        .response
        
        // MARK: Log Raw Response
        let statusCode = afResponse.response?.statusCode ?? -1
        Logger.debugPrint("⬅️ RESPONSE ← \(url) [\(statusCode)]")
        if let data = afResponse.data,
           let str = String(data: data, encoding: .utf8) {
            Logger.debugPrint("📨 Response Body:\n\(str)")
        }
        
        // MARK: Handle Result
        switch afResponse.result {
        case .success(let data):
            // Validate Status Code
            guard (200...299).contains(statusCode) else {
                if statusCode == 401 {
                    throw APIError.unauthorized
                } else {
                    throw APIError.server(statusCode)
                }
            }
            
            // Decode JSON
            do {
                let decoded = try JSONDecoder().decode(R.self, from: data)
                return decoded
            } catch {
                Logger.debugPrint("❌ JSON Decoding failed: \(error.localizedDescription)")
                throw APIError.decoding(error)
            }
            
        case .failure(let error):
            // If the interceptor failed to refresh or other network error occurred
            if let responseCode = afResponse.response?.statusCode {
                 if responseCode == 401 {
                     throw APIError.unauthorized
                 }
                 throw APIError.server(responseCode)
            }
            throw APIError.network(error)
        }
    }
}
