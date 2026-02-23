//
//  CredentialInputDialog.swift
//  LLM Vault
//

import SwiftUI

struct AddCredentialView: View {
    @Environment(\.dismiss) var dismiss
    @State private var keyName: String = ""
    @State private var value: String = ""

    let onAdd: (String, String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Credential")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g. AWS_ACCESS_KEY_ID", text: $keyName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Value")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("Secret value", text: $value)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { onAdd(keyName.trimmingCharacters(in: .whitespaces), value) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(keyName.trimmingCharacters(in: .whitespaces).isEmpty || value.isEmpty)
            }
        }
        .padding()
        .frame(width: 380)
    }
}
