//
//  NetworkManager.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import Foundation


final class NetworkManager {
    static let shared = NetworkManager()

    func performRequest(url: String, body: [String: Any]) async {
        guard let requestURL = URL(string: url) else { return }

        do {
            // Encode request
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            
            // Create request
            var request = URLRequest(url: requestURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            // Print full request
            Logger.log("➡️ REQUEST to \(url):")
            if let requestBody = String(data: jsonData, encoding: .utf8) {
                Logger.debugPrint(requestBody)
            }

            // Perform request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Print raw HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                Logger.log("⬅️ RESPONSE from \(url): Status \(httpResponse.statusCode)")
            }
            
            // Print backend's full response message (exactly what it sent)
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.log("📩 Backend Response:")
                Logger.debugPrint(responseString)
            }

        } catch {
            Logger.log("❌ Network error: \(error.localizedDescription)")
        }
    }

}
