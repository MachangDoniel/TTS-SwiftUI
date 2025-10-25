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
        let fileName = (file as NSString).lastPathComponent
        print("[\(fileName):\(line) \(function)] 🗣 \(message)")
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
        let fileName = (file as NSString).lastPathComponent
        print("[\(fileName):\(line) \(function)] ❌ Error: \(error.localizedDescription)")
        #endif
    }
    
    static func debugPrint(_ message: Any) {
        #if DEBUG
        print(message)
        #endif
    }
}
