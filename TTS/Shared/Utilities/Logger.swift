//
//  Logger.swift
//  TTS
//
//  Created by Doniel Tripura on 10/24/25.
//

import Foundation

/**
 A custom logger designed to output messages ONLY when the app is running in the Debug build configuration.
 
 This prevents sensitive or unnecessary logging information from being exposed in production environments.
 */
struct Logger {
    private enum APILogEmoji {
        static let request = "🚀"
        static let response = "📥"
        static let error = "❌"
        static let divider = "🧭"
    }

    private static func context(file: String, function: String, line: Int) -> String {
        let fileName = (file as NSString).lastPathComponent
        return "[\(fileName):\(line) \(function)]"
    }

    private static func prettyJSONString(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let pretty = String(data: prettyData, encoding: .utf8) else {
            return String(data: data, encoding: .utf8)
        }
        return pretty
    }

    private static func prettyBodyString(from body: Data?) -> String? {
        guard let body, !body.isEmpty else { return nil }
        return prettyJSONString(from: body)
    }

    private static func prettyResponseString(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        return prettyJSONString(from: data)
    }
    
    /**
     Logs a simple informational or warning message.
     
     This function is wrapped in `#if DEBUG` and will be entirely compiled out of the Release build.
     
     - Parameters:
        - message: The string message to display.
        - file: The name of the file where the log occurred (default is the calling file).
        - function: The name of the function where the log occurred (default is the calling function).
        - line: The line number where the log occurred (default is the calling line).
     */
    static func log(_ message: String, 
                    file: String = #file, 
                    function: String = #function, 
                    line: Int = #line) {
        
        #if DEBUG
        print("\(context(file: file, function: function, line: line)) 🗣 \(message)")
        #endif
    }
    
    /**
     Logs a detailed error, including the localized description.
     
     This function is wrapped in `#if DEBUG` and will be entirely compiled out of the Release build.
     
     - Parameters:
        - error: The Error object to log.
        - file: The name of the file where the error occurred (default is the calling file).
        - function: The name of the function where the error occurred (default is the calling function).
        - line: The line number where the error occurred (default is the calling line).
     */
    static func error(_ error: Error, 
                      file: String = #file, 
                      function: String = #function, 
                      line: Int = #line) {
        
        #if DEBUG
        print("\(context(file: file, function: function, line: line)) ❌ Error: \(error.localizedDescription)")
        #endif
    }
    
    static func debugPrint(_ message: Any) {
        #if DEBUG
        print(message)
        #endif
    }

    static func apiRequest(_ request: URLRequest,
                           file: String = #file,
                           function: String = #function,
                           line: Int = #line) {
        let location = context(file: file, function: function, line: line)
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        let headers = request.allHTTPHeaderFields ?? [:]
        let headerLines = headers.isEmpty
            ? "none"
            : headers
                .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
        let body = prettyBodyString(from: request.httpBody) ?? "empty"

        print("""
        \(location) \(APILogEmoji.request) API REQUEST
        \(APILogEmoji.divider) URL: \(url)
        🛠️ Method: \(method)
        🧾 Headers:
        \(headerLines)
        📦 Body:
        \(body)
        """)
    }

    static func apiResponse(url: String,
                            statusCode: Int,
                            data: Data?,
                            file: String = #file,
                            function: String = #function,
                            line: Int = #line) {
        let location = context(file: file, function: function, line: line)
        let responseBody = prettyResponseString(from: data) ?? "empty"
        let statusEmoji = (200...299).contains(statusCode) ? "✅" : "⚠️"

        print("""
        \(location) \(APILogEmoji.response) API RESPONSE
        \(APILogEmoji.divider) URL: \(url)
        \(statusEmoji) Status: \(statusCode)
        📨 Response:
        \(responseBody)
        """)
    }

    static func apiError(_ message: String,
                         file: String = #file,
                         function: String = #function,
                         line: Int = #line) {
        print("\(context(file: file, function: function, line: line)) \(APILogEmoji.error) API ERROR \(message)")
    }
}
