//
//  MenuBarView.swift
//  LLM Vault
//

import SwiftUI

struct MenuBarView: View {
    @StateObject private var viewModel = MenuBarViewModel()
    @State private var showingAddCredential = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.blue)
                Text("LLM Vault")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddCredential = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if viewModel.credentials.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "key.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No credentials stored")
                        .foregroundColor(.secondary)
                    Text("Add one using the + button")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.credentials) { credential in
                            CredentialRow(credential: credential)
                                .contextMenu {
                                    Button("Copy Value") {
                                        viewModel.copyToClipboard(credential)
                                    }
                                    Button("Delete", role: .destructive) {
                                        viewModel.deleteCredential(credential)
                                    }
                                }
                        }
                    }
                }
            }

            Divider()

            HStack {
                Text("\(viewModel.credentials.count) credentials")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 300, height: 400)
        .onAppear {
            viewModel.loadCredentials()
        }
        .sheet(isPresented: $showingAddCredential) {
            AddCredentialView { keyName, value in
                viewModel.addCredential(keyName: keyName, value: value)
                showingAddCredential = false
            }
        }
    }
}

struct CredentialRow: View {
    let credential: StoredCredential

    var body: some View {
        HStack {
            Image(systemName: "key.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(credential.keyName)
                    .font(.system(.body, design: .monospaced))

                if let context = credential.context {
                    Text(context)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Text("Added \(credential.createdAt, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if credential.autoInject {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .help("Auto-inject enabled")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

class MenuBarViewModel: ObservableObject {
    @Published var credentials: [StoredCredential] = []
    private let keychainManager = KeychainManager.shared

    func loadCredentials() {
        credentials = keychainManager.listCredentials()
    }

    func addCredential(keyName: String, value: String) {
        keychainManager.storeCredential(keyName: keyName, value: value)
        loadCredentials()
    }

    func deleteCredential(_ credential: StoredCredential) {
        keychainManager.deleteCredential(keyName: credential.keyName)
        loadCredentials()
    }

    func copyToClipboard(_ credential: StoredCredential) {
        if let value = keychainManager.getCredential(keyName: credential.keyName) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        }
    }
}
