//
//  KeychainManager.swift
//  LLM Vault
//

import Foundation
import Security

struct StoredCredential: Identifiable {
    let id = UUID()
    let keyName: String
    let context: String?
    let createdAt: Date
    let autoInject: Bool
}

class KeychainManager {
    static let shared = KeychainManager()
    private let serviceName = "local-llm-vault"

    private init() {}

    func storeCredential(keyName: String, value: String, context: String? = nil) {
        deleteCredential(keyName: keyName)

        guard let valueData = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyName,
            kSecValueData as String: valueData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            print("✓ Stored \(keyName) in Keychain")
            storeMetadata(keyName: keyName, context: context)
        }
    }

    func getCredential(keyName: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }

        return nil
    }

    func deleteCredential(keyName: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: keyName
        ]

        SecItemDelete(query as CFDictionary)
        deleteMetadata(keyName: keyName)
    }

    func listCredentials() -> [StoredCredential] {
        var credentials: [StoredCredential] = []

        guard let metadataDir = getMetadataDirectory() else { return [] }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: metadataDir, includingPropertiesForKeys: nil)

            for file in files where file.pathExtension == "json" {
                let keyName = file.deletingPathExtension().lastPathComponent

                if let metadata = loadMetadata(keyName: keyName) {
                    let credential = StoredCredential(
                        keyName: keyName,
                        context: metadata["context"] as? String,
                        createdAt: (metadata["created_at"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(),
                        autoInject: metadata["auto_inject"] as? Bool ?? true
                    )
                    credentials.append(credential)
                }
            }
        } catch {
            print("Error listing credentials: \(error)")
        }

        return credentials.sorted { $0.createdAt > $1.createdAt }
    }

    private func getMetadataDirectory() -> URL? {
        guard let homeDir = FileManager.default.homeDirectoryForCurrentUser as URL? else {
            return nil
        }

        let metadataDir = homeDir.appendingPathComponent(".local-llm-vault")

        if !FileManager.default.fileExists(atPath: metadataDir.path) {
            try? FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        }

        return metadataDir
    }

    private func storeMetadata(keyName: String, context: String?) {
        guard let metadataDir = getMetadataDirectory() else { return }

        let metadataFile = metadataDir.appendingPathComponent("\(keyName).json")

        let metadata: [String: Any] = [
            "key_name": keyName,
            "context": context ?? "",
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "auto_inject": true,
            "source": "menu_bar_app"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted) {
            try? data.write(to: metadataFile)
        }
    }

    private func loadMetadata(keyName: String) -> [String: Any]? {
        guard let metadataDir = getMetadataDirectory() else { return nil }

        let metadataFile = metadataDir.appendingPathComponent("\(keyName).json")

        guard let data = try? Data(contentsOf: metadataFile),
              let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return metadata
    }

    private func deleteMetadata(keyName: String) {
        guard let metadataDir = getMetadataDirectory() else { return }

        let metadataFile = metadataDir.appendingPathComponent("\(keyName).json")
        try? FileManager.default.removeItem(at: metadataFile)
    }
}
