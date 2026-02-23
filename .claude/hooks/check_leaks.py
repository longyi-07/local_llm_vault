#!/usr/bin/env python3
"""
LLM Vault - PostToolUse Hook
Checks tool output for leaked credential values by comparing against
credentials stored in macOS Keychain under the llm-vault service.
"""

import json
import sys
import subprocess
import os

PAUSE_FLAG = os.path.expanduser("~/.llm-vault/paused")

if os.path.exists(PAUSE_FLAG):
    sys.exit(0)

REGISTRY_PATH = os.path.expanduser("~/.llm-vault/keys.json")
SERVICE_NAME = "llm-vault"

# Minimum credential length to check (avoids false positives on short values)
MIN_CREDENTIAL_LENGTH = 8


def get_registered_keys() -> list[str]:
    if not os.path.exists(REGISTRY_PATH):
        return []
    try:
        with open(REGISTRY_PATH) as f:
            keys = json.load(f)
            return keys if isinstance(keys, list) else []
    except (json.JSONDecodeError, IOError):
        return []


def get_credential_value(key_name: str) -> str | None:
    try:
        result = subprocess.run(
            ['security', 'find-generic-password', '-s', SERVICE_NAME, '-a', key_name, '-w'],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, Exception):
        pass
    return None


def main():
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    tool_response = hook_input.get('tool_response')
    if not tool_response:
        sys.exit(0)

    response_text = json.dumps(tool_response) if not isinstance(tool_response, str) else tool_response

    keys = get_registered_keys()
    if not keys:
        sys.exit(0)

    leaked = []
    for key_name in keys:
        value = get_credential_value(key_name)
        if value and len(value) >= MIN_CREDENTIAL_LENGTH and value in response_text:
            leaked.append(key_name)

    if not leaked:
        sys.exit(0)

    output = {
        "decision": "block",
        "reason": (
            f"⚠️ LLM Vault: credential value(s) detected in tool output: {', '.join(leaked)}. "
            f"Do NOT repeat, display, or reference these values as plain text. "
            f"Always use inline Keychain substitution to avoid exposing credentials:\n"
            f"  KEY=$(security find-generic-password -s llm-vault -a KEY_NAME -w) command ...\n"
            f"Never run the security command standalone."
        )
    }

    print(json.dumps(output))
    sys.exit(0)


if __name__ == '__main__':
    main()
