#!/usr/bin/env python3
"""
LLM Vault - UserPromptSubmit Hook
Prevents users from pasting credentials directly into Claude
This is the PREVENTION layer
"""

import json
import sys
import re


# Common credential patterns
CREDENTIAL_PATTERNS = [
    # Generic API key patterns
    (r'api[_-]?key\s*[:=]\s*["\']?([a-zA-Z0-9_-]{20,})["\']?', 'API Key'),
    (r'secret[_-]?key\s*[:=]\s*["\']?([a-zA-Z0-9_-]{20,})["\']?', 'Secret Key'),
    (r'password\s*[:=]\s*["\']?([a-zA-Z0-9_-]{8,})["\']?', 'Password'),
    (r'token\s*[:=]\s*["\']?([a-zA-Z0-9_-]{20,})["\']?', 'Token'),

    # OpenAI API keys
    (r'sk-[a-zA-Z0-9]{48}', 'OpenAI API Key'),
    (r'sk-proj-[a-zA-Z0-9_-]{48,}', 'OpenAI Project Key'),

    # AWS credentials
    (r'AKIA[0-9A-Z]{16}', 'AWS Access Key'),
    (r'aws_secret_access_key\s*[:=]\s*["\']?([a-zA-Z0-9/+=]{40})["\']?', 'AWS Secret'),

    # GitHub tokens
    (r'ghp_[a-zA-Z0-9]{36}', 'GitHub Personal Access Token'),
    (r'gho_[a-zA-Z0-9]{36}', 'GitHub OAuth Token'),
    (r'ghs_[a-zA-Z0-9]{36}', 'GitHub Server Token'),

    # Slack tokens
    (r'xoxb-[0-9]{10,13}-[a-zA-Z0-9]{24}', 'Slack Bot Token'),
    (r'xoxp-[0-9]{10,13}-[a-zA-Z0-9]{24}', 'Slack User Token'),

    # Stripe keys
    (r'sk_live_[a-zA-Z0-9]{24,}', 'Stripe Secret Key (Live)'),
    (r'sk_test_[a-zA-Z0-9]{24,}', 'Stripe Secret Key (Test)'),
    (r'pk_live_[a-zA-Z0-9]{24,}', 'Stripe Publishable Key (Live)'),

    # JWT tokens
    (r'eyJ[a-zA-Z0-9_-]{10,}\.eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}', 'JWT Token'),

    # Database URLs with credentials
    (r'(?:postgresql|mysql|mongodb)://[^:]+:[^@]+@[^/]+', 'Database URL with Credentials'),

    # Private keys (PEM format)
    (r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', 'Private Key'),

    # Environment variable assignments with secrets
    (r'export [A-Z_]+=["\']?[a-zA-Z0-9_-]{20,}["\']?', 'Environment Variable with Secret'),
]


def detect_credentials(text: str):
    """
    Detect potential credentials in text
    Returns list of (pattern_name, matched_value)
    """
    detections = []

    for pattern, name in CREDENTIAL_PATTERNS:
        matches = re.finditer(pattern, text, re.IGNORECASE | re.MULTILINE)
        for match in matches:
            # Get the matched text (use group 1 if capture group exists, else group 0)
            try:
                matched_value = match.group(1)
            except IndexError:
                matched_value = match.group(0)

            # Truncate for display
            if len(matched_value) > 20:
                display_value = matched_value[:10] + '...' + matched_value[-10:]
            else:
                display_value = matched_value[:5] + '***'

            detections.append((name, display_value, match.start(), match.end()))

    return detections


def main():
    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error parsing input: {e}", file=sys.stderr)
        sys.exit(0)

    # Get user's prompt
    user_message = hook_input.get('user_message', '')

    if not user_message:
        sys.exit(0)

    # Detect credentials
    detections = detect_credentials(user_message)

    if not detections:
        # No credentials detected, allow
        sys.exit(0)

    # Credentials detected! Block and warn user
    print(f"\n🚨 LLM Vault: Detected {len(detections)} potential credential(s) in your message!", file=sys.stderr)

    for name, display_value, start, end in detections:
        print(f"   - {name}: {display_value}", file=sys.stderr)

    # Create helpful error message
    error_message = f"""🚨 **LLM Vault: Credential Leak Prevention**

Detected {len(detections)} potential credential(s) in your message:

"""

    for name, display_value, start, end in detections:
        error_message += f"- **{name}**: `{display_value}`\n"

    error_message += """
**Why was this blocked?**
Pasting credentials directly into Claude exposes them to:
- Conversation history
- Anthropic's servers
- Potential logs and caches

**How to provide credentials securely:**

1. **Let Claude discover it needs credentials naturally**
   - Just run your command (e.g., "deploy to AWS")
   - Claude will fail and ask for the missing credential
   - LLM Vault will securely prompt you for it

2. **Or use environment variables**
   - Store in your shell: `export AWS_KEY=xxx`
   - Reference by name: "Use $AWS_KEY to deploy"

3. **Manual vault entry**
   - Run: `python3 ~/Desktop/local_llm_vault/lib/ipc_server.py`
   - Credentials stored in macOS Keychain

**Your message was NOT sent to Claude.**

---
*LLM Vault is protecting your secrets. Learn more: ~/Desktop/local_llm_vault/README.md*
"""

    # Block the submission
    output = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "permissionDecision": "deny",
            "permissionDecisionReason": error_message
        }
    }

    print(json.dumps(output, indent=2))
    sys.exit(0)


if __name__ == '__main__':
    main()
