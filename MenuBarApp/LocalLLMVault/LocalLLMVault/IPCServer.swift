//
//  IPCServer.swift
//  LLM Vault
//

import Foundation

protocol IPCServerDelegate: AnyObject {
    func credentialRequested(keyName: String, context: String, completion: @escaping (String?) -> Void)
}

class IPCServer {
    weak var delegate: IPCServerDelegate?
    private let socketPath = "/tmp/llm-vault.sock"
    private var serverSocket: Int32 = -1
    private var isRunning = false

    func start() {
        unlink(socketPath)

        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)

        guard serverSocket >= 0 else {
            print("✗ Failed to create socket")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            socketPath.withCString { cString in
                strcpy(ptr, cString)
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, addrLen)
            }
        }

        guard bindResult >= 0 else {
            print("✗ Failed to bind socket")
            close(serverSocket)
            return
        }

        chmod(socketPath, 0o600)

        guard listen(serverSocket, 5) >= 0 else {
            print("✗ Failed to listen on socket")
            close(serverSocket)
            return
        }

        isRunning = true
        print("✓ IPC server listening on \(socketPath)")

        DispatchQueue.global(qos: .userInitiated).async {
            self.acceptConnections()
        }
    }

    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
        unlink(socketPath)
    }

    private func acceptConnections() {
        while isRunning {
            let clientSocket = accept(serverSocket, nil, nil)

            guard clientSocket >= 0 else { continue }

            DispatchQueue.global(qos: .userInitiated).async {
                self.handleClient(socket: clientSocket)
            }
        }
    }

    private func handleClient(socket: Int32) {
        defer { close(socket) }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(socket, &buffer, buffer.count)

        guard bytesRead > 0,
              let jsonData = Data(buffer.prefix(bytesRead)) as Data?,
              let request = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let action = request["action"] as? String else {
            return
        }

        print("📨 IPC request: \(action)")

        var response: [String: Any]

        switch action {
        case "get_credential":
            response = handleGetCredential(request)
        case "store_credential":
            response = handleStoreCredential(request)
        case "list_credentials":
            response = handleListCredentials()
        case "delete_credential":
            response = handleDeleteCredential(request)
        default:
            response = ["status": "error", "message": "Unknown action"]
        }

        if let responseData = try? JSONSerialization.data(withJSONObject: response),
           let responseBytes = [UInt8](responseData) as [UInt8]? {
            write(socket, responseBytes, responseBytes.count)
        }
    }

    private func handleGetCredential(_ request: [String: Any]) -> [String: Any] {
        guard let keyName = request["key"] as? String else {
            return ["status": "error", "message": "Missing key name"]
        }

        let context = request["context"] as? String ?? ""

        if let value = KeychainManager.shared.getCredential(keyName: keyName) {
            return [
                "status": "ok",
                "credential": value,
                "source": "keychain"
            ]
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result: String?

        delegate?.credentialRequested(keyName: keyName, context: context) { value in
            result = value
            semaphore.signal()
        }

        let timeout = DispatchTime.now() + .seconds(120)
        let waitResult = semaphore.wait(timeout: timeout)

        if waitResult == .timedOut {
            return ["status": "error", "message": "Timeout waiting for user input"]
        }

        if let value = result {
            return [
                "status": "ok",
                "credential": value,
                "source": "user_input"
            ]
        } else {
            return ["status": "cancelled", "message": "User cancelled"]
        }
    }

    private func handleStoreCredential(_ request: [String: Any]) -> [String: Any] {
        guard let keyName = request["key"] as? String,
              let value = request["value"] as? String else {
            return ["status": "error", "message": "Missing key or value"]
        }

        let context = request["context"] as? String
        KeychainManager.shared.storeCredential(keyName: keyName, value: value, context: context)

        return ["status": "ok", "message": "Stored"]
    }

    private func handleListCredentials() -> [String: Any] {
        let credentials = KeychainManager.shared.listCredentials()

        let credentialDicts = credentials.map { credential in
            return [
                "key_name": credential.keyName,
                "context": credential.context ?? "",
                "created_at": ISO8601DateFormatter().string(from: credential.createdAt),
                "auto_inject": credential.autoInject
            ] as [String : Any]
        }

        return [
            "status": "ok",
            "credentials": credentialDicts
        ]
    }

    private func handleDeleteCredential(_ request: [String: Any]) -> [String: Any] {
        guard let keyName = request["key"] as? String else {
            return ["status": "error", "message": "Missing key name"]
        }

        KeychainManager.shared.deleteCredential(keyName: keyName)

        return ["status": "ok", "message": "Deleted"]
    }

    deinit {
        stop()
    }
}
