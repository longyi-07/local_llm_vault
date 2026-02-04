//
//  CredentialInputDialog.swift
//  LLM Vault
//

import SwiftUI
import AppKit

class CredentialInputDialog {
    let keyName: String
    let context: String
    let completion: (String?) -> Void

    init(keyName: String, context: String, completion: @escaping (String?) -> Void) {
        self.keyName = keyName
        self.context = context
        self.completion = completion
    }

    func show() {
        let alert = NSAlert()
        alert.messageText = "🔐 Credential Required"
        alert.informativeText = """
        Claude needs: \(keyName)

        Context: \(context)

        This credential will be stored securely in macOS Keychain.
        """

        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let inputTextField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputTextField.placeholderString = "Enter \(keyName)"

        alert.accessoryView = inputTextField
        alert.window.initialFirstResponder = inputTextField

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let value = inputTextField.stringValue

            if !value.isEmpty {
                KeychainManager.shared.storeCredential(keyName: keyName, value: value, context: context)
                completion(value)
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }
}

struct AddCredentialView: View {
    @Environment(\.dismiss) var dismiss
    @State private var keyName: String = ""
    @State private var value: String = ""

    let onAdd: (String, String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Credential")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Credential Name")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("e.g., AWS_ACCESS_KEY_ID", text: $keyName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Value")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("Enter secret value", text: $value)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    onAdd(keyName, value)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(keyName.isEmpty || value.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
