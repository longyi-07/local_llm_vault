//
//  SettingsView.swift
//  LLM Vault
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = false
    @State private var hooksInstalled = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var credentialCount = 0

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
            } header: {
                Text("General")
            }

            Section {
                HStack {
                    Text("Hooks")
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: hooksInstalled
                            ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(hooksInstalled ? .green : .orange)
                        Text(hooksInstalled ? "Installed" : "Not Installed")
                            .foregroundColor(.secondary)
                    }
                }

                Button(hooksInstalled ? "Reinstall Hooks" : "Install Hooks") {
                    installHooks()
                }

                if hooksInstalled {
                    Button("Uninstall Hooks", role: .destructive) {
                        uninstallHooks()
                    }
                }
            } header: {
                Text("Claude Code Integration")
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("0.2.0").foregroundColor(.secondary)
                }
                HStack {
                    Text("Credentials Stored")
                    Spacer()
                    Text("\(credentialCount)").foregroundColor(.secondary)
                }
                HStack {
                    Text("Keychain Service")
                    Spacer()
                    Text("llm-vault")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Settings")
                    Spacer()
                    Text("~/.claude/settings.json")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 380)
        .onAppear {
            launchAtLogin = getLaunchAtLoginStatus()
            hooksInstalled = HookInstaller.shared.areHooksInstalled()
            credentialCount = KeychainManager.shared.listCredentials().count
        }
        .alert("LLM Vault", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Launch at login error: \(error)")
            }
        }
    }

    private func getLaunchAtLoginStatus() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func installHooks() {
        do {
            try HookInstaller.shared.installHooks()
            hooksInstalled = true
            alertMessage = "Hooks installed successfully."
            showingAlert = true
        } catch {
            alertMessage = "Failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func uninstallHooks() {
        do {
            try HookInstaller.shared.uninstallHooks()
            hooksInstalled = false
            alertMessage = "Hooks uninstalled."
            showingAlert = true
        } catch {
            alertMessage = "Failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}
