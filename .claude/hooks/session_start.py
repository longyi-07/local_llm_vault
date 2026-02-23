#!/usr/bin/env python3
"""
LLM Vault - SessionStart Hook
Injects secure credential usage instructions into Claude's context.
Fires on session start, resume, clear, and compact (so instructions survive compaction).
"""

import json
import os
import sys

PAUSE_FLAG = os.path.expanduser("~/.llm-vault/paused")

if os.path.exists(PAUSE_FLAG):
    sys.exit(0)

INSTRUCTIONS = """
## LLM Vault — Secure Credential Handling

You have access to credentials stored in macOS Keychain via the `vault` CLI at `~/.llm-vault/hooks/vault`.

### Retrieving credentials — ALWAYS use inline substitution

```
API_KEY=$(~/.llm-vault/hooks/vault get KEY_NAME) some-command --key "$API_KEY"
```

Multiple credentials:

```
AWS_ACCESS_KEY_ID=$(~/.llm-vault/hooks/vault get AWS_ACCESS_KEY_ID) \\
AWS_SECRET_ACCESS_KEY=$(~/.llm-vault/hooks/vault get AWS_SECRET_ACCESS_KEY) \\
  aws s3 cp build/ s3://bucket/
```

### Rules — never break these

1. NEVER run `vault get` or `security find-generic-password -w` as a standalone command.
   The value would leak into conversation history.
2. NEVER echo, print, log, or write a credential value to any file or output.
3. NEVER ask the user to paste, type, or share a credential in the chat.
4. NEVER hardcode a credential value in any file.

### When a credential is missing

Guide the user to store it:

    ~/.llm-vault/hooks/vault store KEY_NAME

Or use the LLM Vault menu bar app. After storing, retry — the inline substitution picks it up.

### Checking what's available (names only, never values)

```
~/.llm-vault/hooks/vault list
~/.llm-vault/hooks/vault check KEY_NAME
```
""".strip()

output = {
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": INSTRUCTIONS
    }
}

print(json.dumps(output))
