//
//  HookInstaller.swift
//  LLM Vault
//

import Foundation

enum HookInstallerError: Error, LocalizedError {
    case hooksNotFoundInBundle
    case fileSystemError(String)
    case jsonParsingError(String)

    var errorDescription: String? {
        switch self {
        case .hooksNotFoundInBundle:
            return "Hook scripts not found in app bundle"
        case .fileSystemError(let detail):
            return "File system error: \(detail)"
        case .jsonParsingError(let detail):
            return "JSON error: \(detail)"
        }
    }
}

class HookInstaller {
    static let shared = HookInstaller()

    private let claudeSettingsPath: String = {
        "\(NSHomeDirectory())/.claude/settings.json"
    }()

    private let vaultHooksDir: String = {
        "\(NSHomeDirectory())/.llm-vault/hooks"
    }()

    private let marker = "~/.llm-vault/hooks/"

    private let hookFiles = [
        "block_secrets.py",
        "check_leaks.py",
        "session_start.py",
        "vault.py"
    ]

    private let hooksConfig: [String: Any] = [
        "SessionStart": [
            ["hooks": [
                ["type": "command",
                 "command": "python3 ~/.llm-vault/hooks/session_start.py",
                 "timeout": 5]
            ]]
        ],
        "UserPromptSubmit": [
            ["hooks": [
                ["type": "command",
                 "command": "python3 ~/.llm-vault/hooks/block_secrets.py",
                 "timeout": 5]
            ]]
        ],
        "PostToolUse": [
            ["matcher": "Bash",
             "hooks": [
                ["type": "command",
                 "command": "python3 ~/.llm-vault/hooks/check_leaks.py",
                 "timeout": 10]
            ]]
        ]
    ]

    func areHooksInstalled() -> Bool {
        guard FileManager.default.fileExists(atPath: claudeSettingsPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: claudeSettingsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return false
        }

        for (_, groups) in hooks {
            guard let groups = groups as? [[String: Any]] else { continue }
            for group in groups {
                guard let hookList = group["hooks"] as? [[String: Any]] else { continue }
                for hook in hookList {
                    if let cmd = hook["command"] as? String, cmd.contains(marker) {
                        return true
                    }
                }
            }
        }
        return false
    }

    func installHooks() throws {
        let fm = FileManager.default

        // 1. Create hooks directory
        try fm.createDirectory(atPath: vaultHooksDir, withIntermediateDirectories: true)

        // 2. Try to copy hook scripts from bundle, fall back to already-installed
        let bundlePath = Bundle.main.resourcePath ?? ""
        var copiedFromBundle = false

        for file in hookFiles {
            let bundleSrc = "\(bundlePath)/\(file)"
            let dst = "\(vaultHooksDir)/\(file)"

            if fm.fileExists(atPath: bundleSrc) {
                if fm.fileExists(atPath: dst) {
                    try fm.removeItem(atPath: dst)
                }
                try fm.copyItem(atPath: bundleSrc, toPath: dst)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dst)
                copiedFromBundle = true
            }
        }

        // If we didn't copy from bundle, verify hooks already exist at destination
        if !copiedFromBundle {
            let allExist = hookFiles.allSatisfy {
                fm.fileExists(atPath: "\(vaultHooksDir)/\($0)")
            }
            if !allExist {
                throw HookInstallerError.hooksNotFoundInBundle
            }
        }

        // 3. Initialize registry if needed
        let registryPath = "\(NSHomeDirectory())/.llm-vault/keys.json"
        if !fm.fileExists(atPath: registryPath) {
            try "[]".write(toFile: registryPath, atomically: true, encoding: .utf8)
        }

        // 4. Merge hooks into Claude settings
        try mergeHooksIntoSettings()
    }

    func uninstallHooks() throws {
        let fm = FileManager.default

        // 1. Remove hooks from settings
        try removeHooksFromSettings()

        // 2. Remove hook scripts
        if fm.fileExists(atPath: vaultHooksDir) {
            try fm.removeItem(atPath: vaultHooksDir)
        }

        // 3. Remove pause flag
        let pausePath = "\(NSHomeDirectory())/.llm-vault/paused"
        if fm.fileExists(atPath: pausePath) {
            try fm.removeItem(atPath: pausePath)
        }
    }

    // MARK: - Private

    private func mergeHooksIntoSettings() throws {
        let settingsURL = URL(fileURLWithPath: claudeSettingsPath)
        let settingsDir = (claudeSettingsPath as NSString).deletingLastPathComponent

        try FileManager.default.createDirectory(atPath: settingsDir, withIntermediateDirectories: true)

        var settings: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        // Remove existing LLM Vault hooks
        if var existingHooks = settings["hooks"] as? [String: Any] {
            for event in existingHooks.keys {
                guard var groups = existingHooks[event] as? [[String: Any]] else { continue }
                groups.removeAll { group in
                    guard let hookList = group["hooks"] as? [[String: Any]] else { return false }
                    return hookList.contains { ($0["command"] as? String)?.contains(marker) == true }
                }
                if groups.isEmpty {
                    existingHooks.removeValue(forKey: event)
                } else {
                    existingHooks[event] = groups
                }
            }
            settings["hooks"] = existingHooks
        }

        // Add our hooks
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for (event, config) in hooksConfig {
            var existing = hooks[event] as? [[String: Any]] ?? []
            if let newGroups = config as? [[String: Any]] {
                existing.append(contentsOf: newGroups)
            }
            hooks[event] = existing
        }
        settings["hooks"] = hooks

        let data = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
        try data.write(to: settingsURL)
    }

    private func removeHooksFromSettings() throws {
        let settingsURL = URL(fileURLWithPath: claudeSettingsPath)
        guard let data = try? Data(contentsOf: settingsURL),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for event in hooks.keys {
            guard var groups = hooks[event] as? [[String: Any]] else { continue }
            groups.removeAll { group in
                guard let hookList = group["hooks"] as? [[String: Any]] else { return false }
                return hookList.contains { ($0["command"] as? String)?.contains(marker) == true }
            }
            if groups.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = groups
            }
        }

        if hooks.isEmpty {
            settings.removeValue(forKey: "hooks")
        } else {
            settings["hooks"] = hooks
        }

        let newData = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
        try newData.write(to: settingsURL)
    }
}
