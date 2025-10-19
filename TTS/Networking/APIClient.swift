//
//  APIClient.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import Foundation
import Alamofire

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
        
        // MARK: Log Request
        let requestData = try JSONEncoder().encode(body)
        if let jsonString = String(data: requestData, encoding: .utf8) {
            print("➡️ REQUEST → \(method.rawValue) \(url)")
            print("📦 Body:")
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
        print("⬅️ RESPONSE ← \(url) [\(statusCode)]")
        if let data = afResponse.data,
           let str = String(data: data, encoding: .utf8) {
            print("📨 Response Body:\n\(str)")
        }
        
        // MARK: Validate Status Code
        guard (200...299).contains(statusCode) else {
            throw AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: statusCode))
        }
        
        // MARK: Decode JSON Response
        guard let data = afResponse.data else {
            throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
        }
        
        do {
            let decoded = try JSONDecoder().decode(R.self, from: data)
            return decoded
        } catch {
            print("❌ JSON Decoding failed:", error.localizedDescription)
            throw error
        }
    }
}

