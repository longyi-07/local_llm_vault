#!/usr/bin/env python3
"""
LLM Vault - PostToolUseFailure Hook
Detects authentication/credential failures in tool execution
This is a backup detection method when tools fail due to missing credentials
"""

import json
import sys
import re


# Patterns for credential-related errors
ERROR_PATTERNS = [
    # Generic auth failures
    (r'authentication failed', 0.9),
    (r'unauthorized', 0.85),
    (r'access denied', 0.85),
    (r'permission denied', 0.8),
    (r'invalid credentials', 0.9),
    (r'invalid api key', 0.95),

    # Specific credential errors
    (r'([A-Z_][A-Z0-9_]+).*not set', 0.9),
    (r'([A-Z_][A-Z0-9_]+).*not found', 0.9),
    (r'([A-Z_][A-Z0-9_]+).*missing', 0.85),
    (r'missing.*([A-Z_][A-Z0-9_]+)', 0.85),

    # Service-specific errors
    (r'aws.*credentials', 0.9),
    (r'Unable to locate credentials', 0.95),
    (r'No credentials found', 0.95),
    (r'github.*authentication', 0.9),
    (r'stripe.*api key', 0.95),
]


def detect_credential_error(error_text: str):
    """
    Detect if an error is credential-related
    Returns (is_credential_error, confidence, matched_patterns)
    """
    if not error_text:
        return False, 0.0, []

    matched_patterns = []

    for pattern, confidence in ERROR_PATTERNS:
        match = re.search(pattern, error_text, re.IGNORECASE | re.MULTILINE)
        if match:
            matched_patterns.append((pattern, confidence, match.group(0)))

    if not matched_patterns:
        return False, 0.0, []

    # Return highest confidence
    max_confidence = max(p[1] for p in matched_patterns)

    return True, max_confidence, matched_patterns


def extract_credential_name(error_text: str):
    """
    Try to extract the credential name from error message
    Returns list of potential credential names
    """
    credential_names = []

    # Pattern: "X not set", "X not found", "missing X"
    patterns = [
        r'([A-Z_][A-Z0-9_]+)\s+(?:not set|not found|is missing)',
        r'missing.*?([A-Z_][A-Z0-9_]+)',
        r'environment variable\s+([A-Z_][A-Z0-9_]+)',
    ]

    for pattern in patterns:
        matches = re.finditer(pattern, error_text, re.IGNORECASE | re.MULTILINE)
        for match in matches:
            credential_names.append(match.group(1).upper())

    return list(set(credential_names))  # Deduplicate


def main():
    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error parsing input: {e}", file=sys.stderr)
        sys.exit(0)

    # Get tool error information
    tool_name = hook_input.get('tool_name', '')
    error_message = hook_input.get('error_message', '')
    tool_input = hook_input.get('tool_input', {})

    if not error_message:
        sys.exit(0)

    # Detect if this is a credential error
    is_cred_error, confidence, patterns = detect_credential_error(error_message)

    if not is_cred_error or confidence < 0.75:
        sys.exit(0)

    # Try to extract credential names
    credential_names = extract_credential_name(error_message)

    # Log detection
    print(f"\n🔐 LLM Vault: Detected credential-related error (confidence: {confidence:.0%})", file=sys.stderr)

    if credential_names:
        print(f"   Missing credentials: {', '.join(credential_names)}", file=sys.stderr)

    print(f"   Patterns matched:", file=sys.stderr)
    for pattern, conf, match_text in patterns[:3]:  # Show top 3
        print(f"     - {match_text} ({conf:.0%})", file=sys.stderr)

    # Add helpful context to the error
    additional_context = f"""

---
💡 **LLM Vault Detected**: This appears to be a credential-related error.

"""

    if credential_names:
        additional_context += f"**Missing credentials**: {', '.join(f'`{c}`' for c in credential_names)}\n\n"

    additional_context += """**Next steps:**
1. Claude will likely ask you to provide the credential - LLM Vault will intercept that
2. Or you can manually add it: Start the vault server and provide the credential
3. Then retry your command - credentials will be auto-injected

The credential will be stored securely in macOS Keychain and never appear in the conversation.
"""

    # Return modified output
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PostToolUseFailure",
            "additionalContext": additional_context
        }
    }

    print(json.dumps(output, indent=2))
    sys.exit(0)


if __name__ == '__main__':
    main()
