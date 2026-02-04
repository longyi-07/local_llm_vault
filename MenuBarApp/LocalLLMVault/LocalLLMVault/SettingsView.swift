//
//  SettingsView.swift
//  LLM Vault
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("autoInjectByDefault") private var autoInjectByDefault = true
    @AppStorage("showNotifications") private var showNotifications = true

    var body: some View {
        Form {
            Section {
                Toggle("Auto-inject credentials by default", isOn: $autoInjectByDefault)
                Toggle("Show notifications", isOn: $showNotifications)
            } header: {
                Text("General")
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("0.1.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("IPC Socket")
                    Spacer()
                    Text("/tmp/llm-vault.sock")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Storage")
                    Spacer()
                    Text("macOS Keychain")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
    }
}
