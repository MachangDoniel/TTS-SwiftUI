//
//  AuthInterceptor.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import Foundation
import Alamofire

// MARK: - Auth Interceptor Implementation
final class AuthInterceptor: RequestInterceptor {
    
    // Weak reference to the global AuthViewModel
    private weak var authVM: AuthViewModel?
    
    init(authVM: AuthViewModel?) {
        self.authVM = authVM
    }

    // MARK: - RequestAdapter
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        Task { @MainActor in
            var adapted = urlRequest
            // Safely read token on the main actor
            let token = authVM?.tokenData?.accessToken
            if let token {
                adapted.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            completion(.success(adapted))
        }
    }

    // MARK: - RequestRetrier
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let response = request.task?.response as? HTTPURLResponse, response.statusCode == 401 else {
            // Not a 401, do not retry
            return completion(.doNotRetry)
        }
        
        // Avoid infinite loops if refresh fails
        if request.retryCount >= 3 {
            return completion(.doNotRetry)
        }

        Logger.debugPrint("⚠️ 401 Unauthorized intercepted. Attempting token refresh...")

        Task {
            guard let vm = authVM else {
                completion(.doNotRetry)
                return
            }
            
            do {
                let refreshed = try await vm.refreshSession()
                if refreshed {
                    await Logger.debugPrint("✅ Token refreshed. Retrying request...")
                    completion(.retry)
                } else {
                    await Logger.debugPrint("❌ Token refresh returned false. Logout.")
                    completion(.doNotRetry)
                }
            } catch {
                await Logger.debugPrint("❌ Token refresh failed: \(error.localizedDescription)")
                completion(.doNotRetry)
            }
        }
    }
}
