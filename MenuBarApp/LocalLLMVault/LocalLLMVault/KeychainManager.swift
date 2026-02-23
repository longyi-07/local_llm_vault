//
//  KeychainManager.swift
//  LLM Vault
//

import Foundation

struct CredentialMetadata: Codable {
    var createdAt: Date
    var lastUsedAt: Date?
    var useCount: Int

    init() {
        createdAt = Date()
        lastUsedAt = nil
        useCount = 0
    }
}

struct StoredCredential: Identifiable {
    let id = UUID()
    let keyName: String
    let metadata: CredentialMetadata
}

class KeychainManager {
    static let shared = KeychainManager()
    private let serviceName = "llm-vault"
    private let vaultDir: URL
    private let registryPath: URL
    private let metadataDir: URL

    private init() {
        vaultDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".llm-vault")
        registryPath = vaultDir.appendingPathComponent("keys.json")
        metadataDir = vaultDir.appendingPathComponent("metadata")

        try? FileManager.default.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: registryPath.path) {
            try? JSONEncoder().encode([String]()).write(to: registryPath)
        }
    }

    // MARK: - Keychain (via security CLI for universal access)

    func storeCredential(keyName: String, value: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "add-generic-password",
            "-s", serviceName,
            "-a", keyName,
            "-w", value,
            "-U"
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                registerKey(keyName)
                if loadMetadata(for: keyName) == nil {
                    saveMetadata(CredentialMetadata(), for: keyName)
                }
                print("✓ Stored \(keyName)")
            }
        } catch {
            print("✗ Failed to store \(keyName): \(error)")
        }
    }

    func updateCredential(keyName: String, value: String) {
        storeCredential(keyName: keyName, value: value)
    }

    func getCredential(keyName: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", serviceName, "-a", keyName, "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {}
        return nil
    }

    func credentialExists(keyName: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", serviceName, "-a", keyName]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    func deleteCredential(keyName: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["delete-generic-password", "-s", serviceName, "-a", keyName]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {}
        deregisterKey(keyName)
        deleteMetadata(for: keyName)
    }

    func listCredentials() -> [StoredCredential] {
        let keys = loadRegisteredKeys()
        return keys.compactMap { keyName in
            guard credentialExists(keyName: keyName) else { return nil }
            let meta = loadMetadata(for: keyName) ?? CredentialMetadata()
            return StoredCredential(keyName: keyName, metadata: meta)
        }
    }

    // MARK: - Usage tracking

    func recordUsage(keyName: String) {
        var meta = loadMetadata(for: keyName) ?? CredentialMetadata()
        meta.lastUsedAt = Date()
        meta.useCount += 1
        saveMetadata(meta, for: keyName)
    }

    // MARK: - Metadata (~/.llm-vault/metadata/)

    private func metadataPath(for keyName: String) -> URL {
        metadataDir.appendingPathComponent("\(keyName).json")
    }

    func loadMetadata(for keyName: String) -> CredentialMetadata? {
        let path = metadataPath(for: keyName)
        guard let data = try? Data(contentsOf: path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CredentialMetadata.self, from: data)
    }

    private func saveMetadata(_ metadata: CredentialMetadata, for keyName: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(metadata) {
            try? data.write(to: metadataPath(for: keyName))
        }
    }

    private func deleteMetadata(for keyName: String) {
        try? FileManager.default.removeItem(at: metadataPath(for: keyName))
    }

    // MARK: - Registry (~/.llm-vault/keys.json)

    func loadRegisteredKeys() -> [String] {
        guard let data = try? Data(contentsOf: registryPath),
              let keys = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return keys
    }

    func registerKey(_ name: String) {
        var keys = loadRegisteredKeys()
        if !keys.contains(name) {
            keys.append(name)
            saveRegisteredKeys(keys)
        }
    }

    func deregisterKey(_ name: String) {
        var keys = loadRegisteredKeys()
        keys.removeAll { $0 == name }
        saveRegisteredKeys(keys)
    }

    private func saveRegisteredKeys(_ keys: [String]) {
        if let data = try? JSONEncoder().encode(keys.sorted()) {
            try? data.write(to: registryPath)
        }
    }
}
