import Foundation
import Security

struct LastfmSession: Equatable {
    var username: String
    var sessionKey: String
}

protocol LastfmSessionStoring {
    func load() -> LastfmSession?
    func save(_ session: LastfmSession)
    func clear()
}

struct KeychainSessionStore: LastfmSessionStoring {
    func load() -> LastfmSession? {
        KeychainStore.load()
    }

    func save(_ session: LastfmSession) {
        KeychainStore.save(session)
    }

    func clear() {
        KeychainStore.clear()
    }
}

/// Persists the Last.fm session key in the macOS Keychain.
enum KeychainStore {
    private static let service = "com.panora.lastfm"
    private static let account = "session"

    static func save(_ session: LastfmSession) {
        let value = "\(session.username)\n\(session.sessionKey)"
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> LastfmSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        let parts = str.components(separatedBy: "\n")
        guard parts.count == 2 else { return nil }
        return LastfmSession(username: parts[0], sessionKey: parts[1])
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
