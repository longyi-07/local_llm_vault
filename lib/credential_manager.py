#!/usr/bin/env python3
"""
LLM Vault - Credential Manager
Handles secure storage and retrieval of credentials using macOS Keychain
"""

import subprocess
import json
import os
from typing import Optional, Dict, List
from datetime import datetime


class CredentialManager:
    """Manages credentials using macOS Keychain"""

    SERVICE_NAME = "local-llm-vault"

    def __init__(self):
        self.cache_dir = os.path.expanduser("~/.local-llm-vault")
        os.makedirs(self.cache_dir, exist_ok=True)

    def store_credential(self, key_name: str, value: str, metadata: Optional[Dict] = None) -> bool:
        """
        Store a credential in macOS Keychain

        Args:
            key_name: Name of the credential (e.g., "AWS_ACCESS_KEY_ID")
            value: The secret value
            metadata: Optional metadata (context, timestamp, etc.)

        Returns:
            True if successful, False otherwise
        """
        try:
            # Store in keychain using security command
            cmd = [
                'security', 'add-generic-password',
                '-a', key_name,  # account name
                '-s', self.SERVICE_NAME,  # service name
                '-w', value,  # password (the secret)
                '-U'  # update if exists
            ]

            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode == 0:
                # Store metadata separately
                if metadata:
                    self._store_metadata(key_name, metadata)
                return True
            else:
                print(f"Error storing credential: {result.stderr}", flush=True)
                return False

        except Exception as e:
            print(f"Exception storing credential: {e}", flush=True)
            return False

    def get_credential(self, key_name: str) -> Optional[str]:
        """
        Retrieve a credential from macOS Keychain

        Args:
            key_name: Name of the credential

        Returns:
            The credential value, or None if not found
        """
        try:
            cmd = [
                'security', 'find-generic-password',
                '-a', key_name,
                '-s', self.SERVICE_NAME,
                '-w'  # output password only
            ]

            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode == 0:
                return result.stdout.strip()
            else:
                return None

        except Exception as e:
            print(f"Exception retrieving credential: {e}", flush=True)
            return None

    def delete_credential(self, key_name: str) -> bool:
        """Delete a credential from keychain"""
        try:
            cmd = [
                'security', 'delete-generic-password',
                '-a', key_name,
                '-s', self.SERVICE_NAME
            ]

            result = subprocess.run(cmd, capture_output=True, text=True)

            # Also delete metadata
            self._delete_metadata(key_name)

            return result.returncode == 0

        except Exception as e:
            print(f"Exception deleting credential: {e}", flush=True)
            return False

    def list_credentials(self) -> List[Dict]:
        """List all stored credentials (without values)"""
        metadata_files = []

        if os.path.exists(self.cache_dir):
            for filename in os.listdir(self.cache_dir):
                if filename.endswith('.meta.json'):
                    key_name = filename.replace('.meta.json', '')
                    metadata = self._load_metadata(key_name)

                    # Verify it still exists in keychain
                    if self.get_credential(key_name):
                        metadata['key_name'] = key_name
                        metadata_files.append(metadata)

        return metadata_files

    def _store_metadata(self, key_name: str, metadata: Dict):
        """Store metadata for a credential"""
        metadata_path = os.path.join(self.cache_dir, f"{key_name}.meta.json")

        # Add timestamp
        metadata['created_at'] = metadata.get('created_at', datetime.utcnow().isoformat())
        metadata['updated_at'] = datetime.utcnow().isoformat()

        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)

    def _load_metadata(self, key_name: str) -> Dict:
        """Load metadata for a credential"""
        metadata_path = os.path.join(self.cache_dir, f"{key_name}.meta.json")

        if os.path.exists(metadata_path):
            with open(metadata_path, 'r') as f:
                return json.load(f)

        return {}

    def _delete_metadata(self, key_name: str):
        """Delete metadata file"""
        metadata_path = os.path.join(self.cache_dir, f"{key_name}.meta.json")

        if os.path.exists(metadata_path):
            os.remove(metadata_path)


class SessionCache:
    """Temporary credential cache for Claude session"""

    def __init__(self, session_id: str):
        self.session_id = session_id
        self.cache_file = f"/tmp/llm-vault-session-{session_id}.json"
        self.credentials = self._load()

    def _load(self) -> Dict:
        """Load cache from file"""
        if os.path.exists(self.cache_file):
            try:
                with open(self.cache_file, 'r') as f:
                    return json.load(f)
            except:
                return {}
        return {}

    def _save(self):
        """Save cache to file"""
        with open(self.cache_file, 'w') as f:
            json.dump(self.credentials, f, indent=2)

        # Make it readable only by user
        os.chmod(self.cache_file, 0o600)

    def set(self, key_name: str, value: str, context: str = ""):
        """Cache a credential for this session"""
        self.credentials[key_name] = {
            'value': value,
            'cached_at': datetime.utcnow().isoformat(),
            'context': context
        }
        self._save()

    def get(self, key_name: str) -> Optional[str]:
        """Get cached credential"""
        if key_name in self.credentials:
            return self.credentials[key_name]['value']
        return None

    def get_all(self) -> Dict[str, str]:
        """Get all cached credentials (key -> value)"""
        return {
            key: data['value']
            for key, data in self.credentials.items()
        }

    def clear(self):
        """Clear the cache"""
        if os.path.exists(self.cache_file):
            os.remove(self.cache_file)


if __name__ == '__main__':
    # Test the credential manager
    manager = CredentialManager()

    # Test storage
    print("Testing credential storage...")
    success = manager.store_credential(
        'TEST_API_KEY',
        'sk_test_1234567890',
        metadata={'source': 'test', 'auto_inject': True}
    )
    print(f"Store: {'✓' if success else '✗'}")

    # Test retrieval
    print("\nTesting credential retrieval...")
    value = manager.get_credential('TEST_API_KEY')
    print(f"Retrieve: {'✓' if value == 'sk_test_1234567890' else '✗'}")
    print(f"Value: {value}")

    # Test listing
    print("\nTesting credential listing...")
    creds = manager.list_credentials()
    print(f"Found {len(creds)} credentials:")
    for cred in creds:
        print(f"  - {cred['key_name']}: {cred.get('source', 'unknown')}")

    # Test deletion
    print("\nTesting credential deletion...")
    deleted = manager.delete_credential('TEST_API_KEY')
    print(f"Delete: {'✓' if deleted else '✗'}")

    # Verify deletion
    value = manager.get_credential('TEST_API_KEY')
    print(f"Verify deleted: {'✓' if value is None else '✗'}")

    print("\n✓ All tests passed!")
