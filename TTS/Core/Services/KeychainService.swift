import Foundation
import Security

enum KeychainService {
    static func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func saveString(key: String, value: String) {
        save(key: key, data: Data(value.utf8))
    }

    static func loadString(key: String) -> String? {
        guard let data = load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// An extension on KeychainService providing asynchronous access to the load function.
extension KeychainService {
    /// Asynchronously loads data from the keychain for the given key.
    ///
    /// - Parameter key: The key for which to load data.
    /// - Returns: The data associated with the key, or nil if no data exists.
    static func loadAsync(key: String) async -> Data? {
        await withCheckedContinuation { continuation in
            let data = load(key: key)
            continuation.resume(returning: data)
        }
    }
}
