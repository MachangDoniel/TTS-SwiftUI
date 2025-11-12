//
//  AppDelegate.swift
//  TTS
//
//  Created by Doniel Tripura on 10/26/25.
//


import UIKit
import GoogleSignIn

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}