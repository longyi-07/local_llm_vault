#!/bin/bash
set -euo pipefail

# LLM Vault uninstaller
# Removes hooks from ~/.claude/settings.json and optionally cleans up credentials

VAULT_DIR="$HOME/.llm-vault"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo "🔐 LLM Vault — Uninstalling..."
echo ""

# 1. Remove hooks from Claude settings
if [ -f "$CLAUDE_SETTINGS" ]; then
    python3 - "$CLAUDE_SETTINGS" << 'PYTHON_SCRIPT'
import json
import sys
import os

settings_path = sys.argv[1]
MARKER = "~/.llm-vault/hooks/"

try:
    with open(settings_path) as f:
        settings = json.load(f)
except (json.JSONDecodeError, IOError):
    print("  ⚠ Could not read settings, skipping")
    sys.exit(0)

hooks = settings.get("hooks", {})
removed = 0

for event_name in list(hooks.keys()):
    before = len(hooks[event_name])
    hooks[event_name] = [
        group for group in hooks[event_name]
        if not any(
            MARKER in h.get("command", "")
            for h in group.get("hooks", [])
        )
    ]
    removed += before - len(hooks[event_name])
    if not hooks[event_name]:
        del hooks[event_name]

if not hooks:
    del settings["hooks"]

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

print(f"  ✓ Removed {removed} hook(s) from {settings_path}")
PYTHON_SCRIPT
else
    echo "  ✓ No Claude settings found, skipping"
fi

# 2. Remove hook scripts
if [ -d "$VAULT_DIR/hooks" ]; then
    rm -rf "$VAULT_DIR/hooks"
    echo "  ✓ Removed hook scripts"
fi

# 3. Remove pause flag
rm -f "$VAULT_DIR/paused"

# 4. Ask about credential cleanup
echo ""
read -p "Remove credential registry (~/.llm-vault/keys.json)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "$VAULT_DIR/keys.json"
    echo "  ✓ Registry removed"
fi

read -p "Remove credentials from macOS Keychain (service: llm-vault)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Delete all credentials under the llm-vault service
    while security delete-generic-password -s llm-vault 2>/dev/null; do
        true
    done
    echo "  ✓ Keychain credentials removed"
fi

# 5. Clean up empty vault directory
if [ -d "$VAULT_DIR" ] && [ -z "$(ls -A "$VAULT_DIR" 2>/dev/null)" ]; then
    rmdir "$VAULT_DIR"
    echo "  ✓ Removed empty $VAULT_DIR"
fi

echo ""
echo "✅ LLM Vault uninstalled."
echo "   Your Claude Code sessions will no longer have LLM Vault protection."
