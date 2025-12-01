//
//  AppDelegate.swift
//  TTS
//
//  Created by Doniel Tripura on 10/26/25.
//


import UIKit
import GoogleSignIn
import Combine

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let user = user {
                NotificationCenter.default.post(name: Notification.Name("GoogleSignInRestored"), object: user)
            } else {
                NotificationCenter.default.post(name: Notification.Name("GoogleSignInRestored"), object: nil)
            }
        }
        return true
    }
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
