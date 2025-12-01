//
//  SettingsProvider.swift
//  TTS
//
//  Created by Doniel Tripura on 11/10/25.
//

import Foundation
import Combine

struct GoogleUserInfo: Codable {
    let iss: String
    let azp: String
    let aud: String
    let sub: String
    let email: String
    let emailVerified: String
    let atHash: String
    let nonce: String
    let name: String
    let picture: String
    let givenName: String
    let familyName: String
    let iat: Int
    let exp: Int
    let alg: String
    let kid: String
    let typ: String
    
    enum CodingKeys: String, CodingKey {
        case iss
        case azp
        case aud
        case sub
        case email
        case emailVerified = "email_verified"
        case atHash = "at_hash"
        case nonce
        case name
        case picture
        case givenName = "given_name"
        case familyName = "family_name"
        case iat
        case exp
        case alg
        case kid
        case typ
    }
}

final class SettingsProvider: ObservableObject {
    static let shared = SettingsProvider()
    
    private enum Keys {
        static let name = "settings.name"
        static let email = "settings.email"
        static let pictureURL = "settings.pictureURL"
        static let givenName = "settings.givenName"
        static let familyName = "settings.familyName"
    }

    private var cancellables = Set<AnyCancellable>()
    
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var pictureURL: String = ""
    @Published var givenName: String = ""
    @Published var familyName: String = ""
    
    private init() {
        // Load from local DB (UserDefaults used as lightweight local store)
        name = UserDefaults.standard.string(forKey: Keys.name) ?? ""
        email = UserDefaults.standard.string(forKey: Keys.email) ?? ""
        pictureURL = UserDefaults.standard.string(forKey: Keys.pictureURL) ?? ""
        givenName = UserDefaults.standard.string(forKey: Keys.givenName) ?? ""
        familyName = UserDefaults.standard.string(forKey: Keys.familyName) ?? ""

        // Persist changes automatically
        $name.dropFirst().sink { UserDefaults.standard.set($0, forKey: Keys.name) }.store(in: &cancellables)
        $email.dropFirst().sink { UserDefaults.standard.set($0, forKey: Keys.email) }.store(in: &cancellables)
        $pictureURL.dropFirst().sink { UserDefaults.standard.set($0, forKey: Keys.pictureURL) }.store(in: &cancellables)
        $givenName.dropFirst().sink { UserDefaults.standard.set($0, forKey: Keys.givenName) }.store(in: &cancellables)
        $familyName.dropFirst().sink { UserDefaults.standard.set($0, forKey: Keys.familyName) }.store(in: &cancellables)
    }
    
    func loadFromGoogleUserInfo(_ info: GoogleUserInfo) {
        name = info.name
        email = info.email
        pictureURL = info.picture
        givenName = info.givenName
        familyName = info.familyName
    }
    
    func loadDefaultsFromJSON(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }
        do {
            let info = try JSONDecoder().decode(GoogleUserInfo.self, from: data)
            loadFromGoogleUserInfo(info)
        } catch {
            Logger.log("Failed to decode GoogleUserInfo from JSON: \(error)")
        }
    }
    
    func clearLocalProfile() {
        name = ""
        email = ""
        pictureURL = ""
        givenName = ""
        familyName = ""
        // Values will be persisted via the sinks set up in init()
    }
    
    static let sampleJSON = """
    {
      "iss": "https://accounts.google.com",
      "azp": "1234567890.apps.googleusercontent.com",
      "aud": "1234567890.apps.googleusercontent.com",
      "sub": "123456789012345678901",
      "email": "john.doe@example.com",
      "email_verified": "true",
      "at_hash": "HK6E_P6Dh8Y93mRNtsDB1Q",
      "nonce": "0394852-3190485-2490358",
      "name": "John Doe",
      "picture": "https://lh3.googleusercontent.com/a-/AOh14Gi1vZ5jN6TW2Wg",
      "given_name": "John",
      "family_name": "Doe",
      "iat": 1433978353,
      "exp": 1433981953,
      "alg": "RS256",
      "kid": "123abc",
      "typ": "JWT"
    }
    """
}
