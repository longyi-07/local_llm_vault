#!/usr/bin/env python3
"""
LLM Vault - Credential registry and Keychain helpers.

Manages ~/.llm-vault/keys.json (key names only, never values) and provides
a CLI for basic credential operations.

Usage:
    python3 vault.py store  KEY_NAME          # store credential in Keychain + register
    python3 vault.py check  KEY_NAME          # check if credential exists (no value shown)
    python3 vault.py list                     # list registered key names
    python3 vault.py remove KEY_NAME          # remove from Keychain + deregister
    python3 vault.py verify                   # verify all registered keys exist in Keychain
"""

import json
import os
import subprocess
import sys

REGISTRY_DIR = os.path.expanduser("~/.llm-vault")
REGISTRY_PATH = os.path.join(REGISTRY_DIR, "keys.json")
SERVICE_NAME = "llm-vault"


def _ensure_registry():
    os.makedirs(REGISTRY_DIR, exist_ok=True)
    if not os.path.exists(REGISTRY_PATH):
        with open(REGISTRY_PATH, 'w') as f:
            json.dump([], f)


def _load_keys() -> list[str]:
    _ensure_registry()
    try:
        with open(REGISTRY_PATH) as f:
            keys = json.load(f)
            return keys if isinstance(keys, list) else []
    except (json.JSONDecodeError, IOError):
        return []


def _save_keys(keys: list[str]):
    _ensure_registry()
    with open(REGISTRY_PATH, 'w') as f:
        json.dump(sorted(set(keys)), f, indent=2)


def _keychain_has(key_name: str) -> bool:
    result = subprocess.run(
        ['security', 'find-generic-password', '-s', SERVICE_NAME, '-a', key_name],
        capture_output=True, timeout=5
    )
    return result.returncode == 0


def store(key_name: str):
    """Store a credential in Keychain and register the key name."""
    result = subprocess.run(
        ['security', 'add-generic-password', '-s', SERVICE_NAME, '-a', key_name, '-w', '-U'],
        timeout=30
    )
    if result.returncode != 0:
        print(f"Failed to store {key_name} in Keychain", file=sys.stderr)
        sys.exit(1)

    keys = _load_keys()
    if key_name not in keys:
        keys.append(key_name)
        _save_keys(keys)

    print(f"✓ {key_name} stored in Keychain and registered")


def check(key_name: str):
    """Check if a credential exists in Keychain (no value shown)."""
    if _keychain_has(key_name):
        print(f"✓ {key_name}: found in Keychain")
    else:
        print(f"✗ {key_name}: not found in Keychain")
        sys.exit(1)


def list_keys():
    """List all registered key names."""
    keys = _load_keys()
    if not keys:
        print("No credentials registered. Store one with:")
        print("  security add-generic-password -s llm-vault -a KEY_NAME -w")
        return

    print(f"{len(keys)} registered credential(s):")
    for key in sorted(keys):
        status = "✓" if _keychain_has(key) else "✗ missing from Keychain"
        print(f"  {status} {key}")


def remove(key_name: str):
    """Remove credential from Keychain and deregister."""
    subprocess.run(
        ['security', 'delete-generic-password', '-s', SERVICE_NAME, '-a', key_name],
        capture_output=True, timeout=5
    )
    keys = _load_keys()
    keys = [k for k in keys if k != key_name]
    _save_keys(keys)
    print(f"✓ {key_name} removed")


def verify():
    """Verify all registered keys exist in Keychain."""
    keys = _load_keys()
    if not keys:
        print("No credentials registered.")
        return

    ok, missing = 0, 0
    for key in sorted(keys):
        if _keychain_has(key):
            print(f"  ✓ {key}")
            ok += 1
        else:
            print(f"  ✗ {key} — missing from Keychain")
            missing += 1

    print(f"\n{ok} found, {missing} missing")
    if missing:
        sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip())
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == 'store' and len(sys.argv) == 3:
        store(sys.argv[2])
    elif cmd == 'check' and len(sys.argv) == 3:
        check(sys.argv[2])
    elif cmd == 'list':
        list_keys()
    elif cmd == 'remove' and len(sys.argv) == 3:
        remove(sys.argv[2])
    elif cmd == 'verify':
        verify()
    else:
        print(__doc__.strip())
        sys.exit(1)


if __name__ == '__main__':
    main()
