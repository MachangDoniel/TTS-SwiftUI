//
//  APIClient.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import Foundation
import Alamofire

// MARK: - SessionExpiredError definition
struct SessionExpiredError: Error {}

// MARK: - Weak AuthViewModel singleton for APIClient integration
private weak var globalAuthVM: AuthViewModel? = nil
func setGlobalAuthViewModel(_ vm: AuthViewModel) { globalAuthVM = vm }

final class APIClient {
    static let shared = APIClient()
    private init() {}
    
    func request<T: Encodable, R: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .post,
        body: T,
        headers: HTTPHeaders? = nil
    ) async throws -> R {
        
        let url = APIEndpoints.baseURL + endpoint
        
        // MARK: - Prepare headers with Authorization if token available
        var updatedHeaders: HTTPHeaders = headers ?? HTTPHeaders()
        if let token = await globalAuthVM?.tokenData?.accessToken {
            updatedHeaders.add(name: "Authorization", value: "Bearer \(token)")
        }
        
        // MARK: - Function to perform request once with given headers
        func performRequest(with headers: HTTPHeaders) async throws -> R {
            // MARK: Log Request
            let requestData = try JSONEncoder().encode(body)
            if let jsonString = String(data: requestData, encoding: .utf8) {
                Logger.debugPrint("➡️ REQUEST → \(method.rawValue) \(url)")
                Logger.debugPrint("📦 Body:")
                print(jsonString)
            }
            
            // MARK: Send Request
            let afResponse = await AF.request(
                url,
                method: method,
                parameters: body,
                encoder: JSONParameterEncoder.default,
                headers: headers
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
            
            // MARK: Validate Status Code
            guard (200...299).contains(statusCode) else {
                if statusCode == 401 {
                    // Let caller handle 401 specially
                    throw AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 401))
                } else {
                    throw AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: statusCode))
                }
            }
            
            // MARK: Decode JSON Response
            guard let data = afResponse.data else {
                throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
            }
            
            do {
                let decoded = try JSONDecoder().decode(R.self, from: data)
                return decoded
            } catch {
                Logger.debugPrint("❌ JSON Decoding failed: \(error.localizedDescription)")
                throw error
            }
        }
        
        // MARK: - Token refresh logic and retry on 401
        do {
            // Try initial request
            return try await performRequest(with: updatedHeaders)
        } catch let afError as AFError {
            if case .responseValidationFailed(reason: .unacceptableStatusCode(code: 401)) = afError {
                // Unauthorized: try refresh session
                Logger.debugPrint("⚠️ 401 Unauthorized received, attempting token refresh...")
                if let refreshed = try? await globalAuthVM?.refreshSession(), refreshed == true {
                    // Refresh succeeded, update headers with new token and retry once
                    var retryHeaders: HTTPHeaders = headers ?? HTTPHeaders()
                    if let newToken = await globalAuthVM?.tokenData?.accessToken {
                        retryHeaders.add(name: "Authorization", value: "Bearer \(newToken)")
                    }
                    Logger.debugPrint("🔄 Retrying request with refreshed token...")
                    return try await performRequest(with: retryHeaders)
                } else {
                    // Refresh failed or tokens invalid
                    Logger.debugPrint("❌ Token refresh failed, clearing tokens and throwing SessionExpiredError")
                    await globalAuthVM?.clearTokenData()
                    throw SessionExpiredError()
                }
            } else {
                throw afError
            }
        }
    }
}
