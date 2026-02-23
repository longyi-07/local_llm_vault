#!/usr/bin/env python3
"""
LLM Vault - UserPromptSubmit Hook
Blocks credentials pasted directly into Claude prompts.
"""

import json
import os
import sys
import re

PAUSE_FLAG = os.path.expanduser("~/.llm-vault/paused")

if os.path.exists(PAUSE_FLAG):
    sys.exit(0)

PATTERNS = [
    # OpenAI
    (r'sk-[a-zA-Z0-9]{20,}', 'OpenAI API Key'),
    (r'sk-proj-[a-zA-Z0-9\-_]{40,}', 'OpenAI Project Key'),

    # Anthropic
    (r'sk-ant-[a-zA-Z0-9\-_]{40,}', 'Anthropic API Key'),

    # AWS
    (r'AKIA[0-9A-Z]{16}', 'AWS Access Key ID'),
    (r'(?<![A-Za-z0-9/+=])[A-Za-z0-9/+=]{40}(?![A-Za-z0-9/+=])', None),  # AWS Secret (checked with context)

    # GitHub
    (r'ghp_[a-zA-Z0-9]{36,}', 'GitHub Personal Access Token'),
    (r'gho_[a-zA-Z0-9]{36,}', 'GitHub OAuth Token'),
    (r'ghs_[a-zA-Z0-9]{36,}', 'GitHub App Token'),
    (r'ghu_[a-zA-Z0-9]{36,}', 'GitHub User-to-Server Token'),
    (r'github_pat_[a-zA-Z0-9_]{22,}', 'GitHub Fine-Grained PAT'),

    # Stripe
    (r'sk_live_[a-zA-Z0-9]{24,}', 'Stripe Secret Key'),
    (r'sk_test_[a-zA-Z0-9]{24,}', 'Stripe Test Key'),
    (r'rk_live_[a-zA-Z0-9]{24,}', 'Stripe Restricted Key'),

    # Slack
    (r'xoxb-[0-9]{10,}-[a-zA-Z0-9\-]+', 'Slack Bot Token'),
    (r'xoxp-[0-9]{10,}-[a-zA-Z0-9\-]+', 'Slack User Token'),
    (r'xoxs-[0-9]{10,}-[a-zA-Z0-9\-]+', 'Slack Session Token'),

    # Google
    (r'AIza[0-9A-Za-z_\-]{35}', 'Google API Key'),
    (r'ya29\.[0-9A-Za-z_\-]+', 'Google OAuth Token'),

    # Private keys
    (r'-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----', 'Private Key'),

    # Generic high-entropy tokens assigned to known env vars
    (r'(?:api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token)\s*[:=]\s*["\']?([a-zA-Z0-9_\-]{20,})["\']?', 'Credential Assignment'),

    # Database URLs with passwords
    (r'(?:postgres|mysql|mongodb|redis)://[^:]+:[^@]+@', 'Database URL with Password'),

    # Package registry tokens
    (r'npm_[a-zA-Z0-9]{36}', 'npm Token'),
    (r'pypi-[a-zA-Z0-9]{60,}', 'PyPI Token'),

    # SendGrid
    (r'SG\.[a-zA-Z0-9_\-]{22}\.[a-zA-Z0-9_\-]{43}', 'SendGrid API Key'),

    # Twilio
    (r'SK[a-f0-9]{32}', 'Twilio API Key'),

    # Mailgun
    (r'key-[a-zA-Z0-9]{32}', 'Mailgun API Key'),

    # Heroku
    (r'[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}', None),  # UUID-like, only with context
]

# Patterns that need surrounding context to avoid false positives
CONTEXT_REQUIRED = {
    'Credential Assignment',
}


def mask(value: str) -> str:
    if len(value) > 16:
        return value[:6] + '***' + value[-4:]
    if len(value) > 8:
        return value[:4] + '***'
    return '***'


def detect(text: str) -> list[tuple[str, str]]:
    found = []
    for pattern, label in PATTERNS:
        if label is None:
            continue
        for match in re.finditer(pattern, text):
            value = match.group(1) if match.lastindex else match.group(0)
            if len(value) < 8:
                continue
            found.append((label, mask(value)))
    return found


def main():
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    prompt = hook_input.get('prompt', '')
    if not prompt:
        sys.exit(0)

    hits = detect(prompt)
    if not hits:
        sys.exit(0)

    lines = [f"🔐 LLM Vault blocked {len(hits)} credential(s):"]
    for label, preview in hits:
        lines.append(f"  • {label}: {preview}")
    lines.append("")
    lines.append("Store credentials securely instead:")
    lines.append("  security add-generic-password -s llm-vault -a KEY_NAME -w")
    lines.append("")
    lines.append("Then ask Claude to retry — it will pick up the credential automatically.")

    print('\n'.join(lines), file=sys.stderr)
    sys.exit(2)


if __name__ == '__main__':
    main()
