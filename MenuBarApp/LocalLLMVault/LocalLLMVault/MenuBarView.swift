//
//  MenuBarView.swift
//  LLM Vault
//

import SwiftUI
import Combine

struct MenuBarView: View {
    @StateObject private var viewModel = MenuBarViewModel()
    @State private var showingAddCredential = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: viewModel.isPaused ? "lock.open" : "lock.shield.fill")
                    .foregroundColor(viewModel.isPaused ? .orange : .blue)
                Text("LLM Vault")
                    .font(.headline)
                Spacer()
                Text(viewModel.isPaused ? "Paused" : "Active")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(viewModel.isPaused
                        ? Color.orange.opacity(0.2)
                        : Color.green.opacity(0.2))
                    .foregroundColor(viewModel.isPaused ? .orange : .green)
                    .cornerRadius(4)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Pause/Resume
            Button(action: {
                viewModel.togglePause()
                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                    appDelegate.updateIcon()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.isPaused
                        ? "play.circle.fill" : "pause.circle.fill")
                    Text(viewModel.isPaused
                        ? "Resume Protection" : "Pause Protection")
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            // Credentials
            if viewModel.credentials.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "key.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("No credentials stored")
                        .foregroundColor(.secondary)
                    Button("Add Credential") {
                        showingAddCredential = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.credentials) { credential in
                            CredentialRow(
                                credential: credential,
                                revealedKey: $viewModel.revealedKey,
                                onUpdate: { viewModel.editingCredential = credential },
                                onDelete: { viewModel.deleteCredential(credential) }
                            )
                            Divider().padding(.leading, 40)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            Divider()

            // Footer
            HStack {
                Text("\(viewModel.credentials.count) credential(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showingAddCredential = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

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
        .frame(width: 340)
        .onAppear {
            viewModel.refresh()
        }
        .sheet(isPresented: $showingAddCredential) {
            AddCredentialView { keyName, value in
                viewModel.addCredential(keyName: keyName, value: value)
                showingAddCredential = false
            }
        }
        .sheet(item: $viewModel.editingCredential) { credential in
            UpdateCredentialView(keyName: credential.keyName) { newValue in
                viewModel.updateCredential(keyName: credential.keyName, value: newValue)
                viewModel.editingCredential = nil
            }
        }
    }
}

// MARK: - Credential Row

struct CredentialRow: View {
    let credential: StoredCredential
    @Binding var revealedKey: String?
    let onUpdate: () -> Void
    let onDelete: () -> Void

    @State private var revealedValue: String?

    private var isRevealed: Bool {
        revealedKey == credential.keyName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.blue)
                    .frame(width: 16)

                Text(credential.keyName)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)

                Spacer()

                // Reveal toggle
                Button(action: toggleReveal) {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "Hide value" : "Reveal value")

                // Context menu via gear icon
                Menu {
                    Button("Update Value...") { onUpdate() }
                    Button("Copy Value") { copyValue() }
                    Divider()
                    Button("Delete", role: .destructive) { onDelete() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
            }

            // Revealed value
            if isRevealed, let value = revealedValue {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.orange)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(4)
            }

            // Metadata
            HStack(spacing: 12) {
                Label(relativeDate(credential.metadata.createdAt), systemImage: "calendar")

                if let lastUsed = credential.metadata.lastUsedAt {
                    Label(relativeDate(lastUsed), systemImage: "clock")
                }

                if credential.metadata.useCount > 0 {
                    Label("\(credential.metadata.useCount)×", systemImage: "arrow.counterclockwise")
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func toggleReveal() {
        if isRevealed {
            revealedKey = nil
            revealedValue = nil
        } else {
            revealedKey = credential.keyName
            revealedValue = KeychainManager.shared.getCredential(keyName: credential.keyName)
        }
    }

    private func copyValue() {
        if let value = KeychainManager.shared.getCredential(keyName: credential.keyName) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Update Credential

struct UpdateCredentialView: View {
    let keyName: String
    let onUpdate: (String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var newValue: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Update Credential")
                .font(.headline)

            Text(keyName)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.blue)

            SecureField("New value", text: $newValue)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Update") { onUpdate(newValue) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newValue.isEmpty)
            }
        }
        .padding()
        .frame(width: 360)
    }
}

// MARK: - View Model

class MenuBarViewModel: ObservableObject {
    @Published var credentials: [StoredCredential] = []
    @Published var isPaused: Bool = false
    @Published var revealedKey: String?
    @Published var editingCredential: StoredCredential?

    func refresh() {
        credentials = KeychainManager.shared.listCredentials()
        isPaused = VaultState.isPaused
        revealedKey = nil
    }

    func addCredential(keyName: String, value: String) {
        KeychainManager.shared.storeCredential(keyName: keyName, value: value)
        refresh()
    }

    func updateCredential(keyName: String, value: String) {
        KeychainManager.shared.updateCredential(keyName: keyName, value: value)
        refresh()
    }

    func deleteCredential(_ credential: StoredCredential) {
        KeychainManager.shared.deleteCredential(keyName: credential.keyName)
        refresh()
    }

    func togglePause() {
        VaultState.toggle()
        isPaused = VaultState.isPaused
    }
}
