#!/usr/bin/env python3
"""
LLM Vault - Stop Hook
Detects when Claude asks for credentials in its response
This is the REACTIVE approach - wait for Claude to identify credential needs
"""

import json
import sys
import re
import os

# Add lib to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lib'))

from credential_manager import SessionCache
from ipc_server import request_credential


def detect_credential_request(text: str):
    """
    Detect if Claude is asking for credentials
    Returns list of (credential_name, confidence_score, pattern_matched)
    """
    detected = []

    # Pattern 1: "Could you provide/set X?"
    matches = re.finditer(
        r'could you (?:provide|set) (?:the )?([A-Z_][A-Z0-9_]+)',
        text,
        re.IGNORECASE | re.MULTILINE
    )
    for match in matches:
        detected.append((match.group(1).upper(), 0.9, 'explicit_request'))

    # Pattern 2: "Please set X environment variable"
    matches = re.finditer(
        r'please set(?: the)? ([A-Z_][A-Z0-9_]+)(?: environment)?',
        text,
        re.IGNORECASE | re.MULTILINE
    )
    for match in matches:
        detected.append((match.group(1).upper(), 0.9, 'please_set'))

    # Pattern 3: "X not found/not set/is missing"
    matches = re.finditer(
        r'([A-Z_][A-Z0-9_]+) (?:not found|not set|is missing|is not set)',
        text,
        re.IGNORECASE | re.MULTILINE
    )
    for match in matches:
        detected.append((match.group(1).upper(), 0.85, 'not_found'))

    # Pattern 4: "You'll need to configure/set X"
    matches = re.finditer(
        r'(?:need to|should) (?:configure|set|provide) (?:the )?([A-Z_][A-Z0-9_]+)',
        text,
        re.IGNORECASE | re.MULTILINE
    )
    for match in matches:
        detected.append((match.group(1).upper(), 0.8, 'need_to'))

    # Pattern 5: "Missing environment variable: X"
    matches = re.finditer(
        r'missing.*(?:variable|key|token|credential).*?:?\s*([A-Z_][A-Z0-9_]+)',
        text,
        re.IGNORECASE | re.MULTILINE
    )
    for match in matches:
        detected.append((match.group(1).upper(), 0.85, 'missing'))

    # Pattern 6: "Set X environment variable"
    matches = re.finditer(
        r'set (?:the )?([A-Z_][A-Z0-9_]+) environment',
        text,
        re.IGNORECASE | re.MULTILINE
    )
    for match in matches:
        detected.append((match.group(1).upper(), 0.7, 'set_env'))

    # Pattern 7: Error messages with credentials
    matches = re.finditer(
        r'(?:error|failed).*?([A-Z_][A-Z0-9_]+).*?(?:not configured|invalid|missing)',
        text,
        re.IGNORECASE | re.MULTILINE
    )
    for match in matches:
        detected.append((match.group(1).upper(), 0.75, 'error_message'))

    # Deduplicate by taking highest confidence for each key
    unique_detections = {}
    for key, confidence, pattern in detected:
        if key not in unique_detections or confidence > unique_detections[key][0]:
            unique_detections[key] = (confidence, pattern)

    return [(key, conf, pattern) for key, (conf, pattern) in unique_detections.items()]


def main():
    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error parsing input: {e}", file=sys.stderr)
        sys.exit(0)

    # Get Claude's response
    assistant_message = hook_input.get('assistant_message', '')

    if not assistant_message:
        sys.exit(0)

    # Get session ID for caching
    session_id = hook_input.get('session_id', 'default')

    # Detect credential requests
    detections = detect_credential_request(assistant_message)

    if not detections:
        sys.exit(0)

    # Filter by confidence threshold
    high_confidence = [(k, c, p) for k, c, p in detections if c >= 0.7]

    if not high_confidence:
        sys.exit(0)

    # Initialize session cache
    cache = SessionCache(session_id)

    # Log detection to stderr (visible in Claude terminal)
    print(f"\n🔐 LLM Vault: Detected {len(high_confidence)} credential request(s)", file=sys.stderr)

    credentials_loaded = []

    for credential_name, confidence, pattern in high_confidence:
        print(f"   - {credential_name} (confidence: {confidence:.0%}, pattern: {pattern})", file=sys.stderr)

        # Check if already in session cache
        cached_value = cache.get(credential_name)

        if cached_value:
            print(f"     ✓ Already cached", file=sys.stderr)
            continue

        # Request credential from IPC server
        response = request_credential(
            credential_name,
            context=f"Claude requested: {assistant_message[:100]}...",
            session_id=session_id
        )

        if response.get('status') == 'ok':
            credential_value = response.get('credential')

            # Cache for this session
            cache.set(credential_name, credential_value, context=assistant_message[:200])

            credentials_loaded.append(credential_name)
            print(f"     ✓ Loaded from {response.get('source', 'unknown')}", file=sys.stderr)

        elif response.get('status') == 'cancelled':
            print(f"     ✗ User cancelled", file=sys.stderr)

        else:
            print(f"     ✗ Error: {response.get('message', 'Unknown error')}", file=sys.stderr)

    # Modify Claude's response to indicate credentials were loaded
    if credentials_loaded:
        additional_context = f"\n\n---\n✓ **LLM Vault**: Loaded {', '.join(f'`{c}`' for c in credentials_loaded)} from secure storage."
        additional_context += "\n\nYou can now retry the command. The credentials will be automatically injected."

        output = {
            "hookSpecificOutput": {
                "hookEventName": "Stop",
                "additionalContext": additional_context
            }
        }

        print(json.dumps(output, indent=2))
        sys.exit(0)

    # No credentials loaded
    sys.exit(0)


if __name__ == '__main__':
    main()
