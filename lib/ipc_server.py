#!/usr/bin/env python3
"""
LLM Vault - IPC Server
Handles communication between hooks and UI
Eventually this will communicate with the Swift menu bar app
For now, it provides a terminal-based interface
"""

import socket
import json
import os
import sys
import threading
from pathlib import Path
from credential_manager import CredentialManager


class VaultIPCServer:
    """IPC server for credential requests"""

    SOCKET_PATH = "/tmp/llm-vault.sock"

    def __init__(self):
        self.credential_manager = CredentialManager()
        self.socket = None

    def start(self):
        """Start the IPC server"""

        # Remove existing socket if present
        if os.path.exists(self.SOCKET_PATH):
            os.remove(self.SOCKET_PATH)

        # Create Unix domain socket
        self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.socket.bind(self.SOCKET_PATH)
        self.socket.listen(5)

        # Make socket accessible
        os.chmod(self.SOCKET_PATH, 0o600)

        print(f"✓ LLM Vault IPC server started at {self.SOCKET_PATH}", flush=True)
        print("Waiting for credential requests from Claude Code hooks...\n", flush=True)

        try:
            while True:
                client, _ = self.socket.accept()
                # Handle each request in a separate thread
                thread = threading.Thread(target=self.handle_request, args=(client,))
                thread.daemon = True
                thread.start()

        except KeyboardInterrupt:
            print("\n✓ Server stopped", flush=True)
            self.stop()

    def handle_request(self, client_socket):
        """Handle a credential request from a hook"""
        try:
            # Receive request data
            data = client_socket.recv(4096)
            if not data:
                return

            request = json.loads(data.decode('utf-8'))
            action = request.get('action')

            print(f"\n📨 Received request: {action}", flush=True)

            if action == 'get_credential':
                response = self._handle_get_credential(request)
            elif action == 'store_credential':
                response = self._handle_store_credential(request)
            elif action == 'list_credentials':
                response = self._handle_list_credentials(request)
            elif action == 'delete_credential':
                response = self._handle_delete_credential(request)
            else:
                response = {'status': 'error', 'message': 'Unknown action'}

            # Send response
            client_socket.send(json.dumps(response).encode('utf-8'))

        except Exception as e:
            error_response = {'status': 'error', 'message': str(e)}
            client_socket.send(json.dumps(error_response).encode('utf-8'))

        finally:
            client_socket.close()

    def _handle_get_credential(self, request):
        """Handle get_credential request"""
        key_name = request.get('key')
        context = request.get('context', '')

        print(f"  🔑 Key: {key_name}", flush=True)
        print(f"  📝 Context: {context}", flush=True)

        # Try to get from keychain
        value = self.credential_manager.get_credential(key_name)

        if value:
            print(f"  ✓ Found in keychain", flush=True)
            return {
                'status': 'ok',
                'credential': value,
                'source': 'keychain'
            }

        # Not found - prompt user (for now, via terminal)
        print(f"\n🔐 Credential Required: {key_name}", flush=True)
        print(f"   Context: {context}", flush=True)
        print(f"   This will be shown in a popup in the menu bar app.", flush=True)

        # For MVP: Get from terminal input
        try:
            user_value = input(f"\n   Enter value for {key_name} (or press Enter to skip): ")

            if user_value:
                # Store in keychain
                metadata = {
                    'source': 'user_input',
                    'context': context,
                    'auto_inject': True
                }
                self.credential_manager.store_credential(key_name, user_value, metadata)

                print(f"   ✓ Stored in keychain", flush=True)

                return {
                    'status': 'ok',
                    'credential': user_value,
                    'source': 'user_input'
                }
            else:
                return {
                    'status': 'cancelled',
                    'message': 'User cancelled'
                }

        except (EOFError, KeyboardInterrupt):
            return {
                'status': 'cancelled',
                'message': 'User cancelled'
            }

    def _handle_store_credential(self, request):
        """Handle store_credential request"""
        key_name = request.get('key')
        value = request.get('value')
        metadata = request.get('metadata', {})

        success = self.credential_manager.store_credential(key_name, value, metadata)

        return {
            'status': 'ok' if success else 'error',
            'message': 'Stored' if success else 'Failed to store'
        }

    def _handle_list_credentials(self, request):
        """Handle list_credentials request"""
        creds = self.credential_manager.list_credentials()

        return {
            'status': 'ok',
            'credentials': creds
        }

    def _handle_delete_credential(self, request):
        """Handle delete_credential request"""
        key_name = request.get('key')

        success = self.credential_manager.delete_credential(key_name)

        return {
            'status': 'ok' if success else 'error',
            'message': 'Deleted' if success else 'Failed to delete'
        }

    def stop(self):
        """Stop the server"""
        if self.socket:
            self.socket.close()

        if os.path.exists(self.SOCKET_PATH):
            os.remove(self.SOCKET_PATH)


def request_credential(key_name: str, context: str = "", session_id: str = "") -> dict:
    """
    Client function to request a credential from the IPC server
    Called by hooks
    """
    try:
        # Connect to IPC server
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(VaultIPCServer.SOCKET_PATH)

        # Send request
        request = {
            'action': 'get_credential',
            'key': key_name,
            'context': context,
            'session_id': session_id
        }

        sock.send(json.dumps(request).encode('utf-8'))

        # Receive response
        response_data = sock.recv(4096)
        response = json.loads(response_data.decode('utf-8'))

        sock.close()

        return response

    except Exception as e:
        return {
            'status': 'error',
            'message': f'Failed to connect to LLM Vault server: {e}'
        }


if __name__ == '__main__':
    # Run the IPC server
    server = VaultIPCServer()
    server.start()
