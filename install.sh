#!/bin/bash
set -euo pipefail

# LLM Vault installer
# Copies hooks to ~/.llm-vault/hooks/ and merges config into ~/.claude/settings.json

VAULT_DIR="$HOME/.llm-vault"
HOOKS_DIR="$VAULT_DIR/hooks"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_HOOKS="$SCRIPT_DIR/.claude/hooks"

echo "🔐 LLM Vault — Installing..."
echo ""

# 1. Create directories
mkdir -p "$HOOKS_DIR"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"

# 2. Copy hook scripts
echo "  Copying hooks to $HOOKS_DIR/"
cp "$SOURCE_HOOKS/block_secrets.py"  "$HOOKS_DIR/"
cp "$SOURCE_HOOKS/check_leaks.py"    "$HOOKS_DIR/"
cp "$SOURCE_HOOKS/session_start.py"  "$HOOKS_DIR/"
cp "$SOURCE_HOOKS/vault.py"          "$HOOKS_DIR/"
cp "$SOURCE_HOOKS/vault"             "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR"/*.py "$HOOKS_DIR/vault"

# Add vault CLI to PATH via symlink
mkdir -p "$HOME/.local/bin"
ln -sf "$HOOKS_DIR/vault" "$HOME/.local/bin/vault"
echo "  ✓ 4 hooks + vault CLI installed"

# 3. Initialize credential registry if it doesn't exist
if [ ! -f "$VAULT_DIR/keys.json" ]; then
    echo '[]' > "$VAULT_DIR/keys.json"
    echo "  ✓ Credential registry created"
fi

# 4. Merge hooks into Claude settings
python3 - "$CLAUDE_SETTINGS" << 'PYTHON_SCRIPT'
import json
import sys
import os
from copy import deepcopy

settings_path = sys.argv[1]

# The hooks LLM Vault needs
VAULT_HOOKS = {
    "SessionStart": [
        {
            "hooks": [
                {
                    "type": "command",
                    "command": "python3 ~/.llm-vault/hooks/session_start.py",
                    "timeout": 5
                }
            ]
        }
    ],
    "UserPromptSubmit": [
        {
            "hooks": [
                {
                    "type": "command",
                    "command": "python3 ~/.llm-vault/hooks/block_secrets.py",
                    "timeout": 5
                }
            ]
        }
    ],
    "PostToolUse": [
        {
            "matcher": "Bash",
            "hooks": [
                {
                    "type": "command",
                    "command": "python3 ~/.llm-vault/hooks/check_leaks.py",
                    "timeout": 10
                }
            ]
        }
    ]
}

MARKER = "~/.llm-vault/hooks/"

# Load existing settings
settings = {}
if os.path.exists(settings_path):
    try:
        with open(settings_path) as f:
            settings = json.load(f)
    except (json.JSONDecodeError, IOError):
        # Back up corrupted file
        backup = settings_path + ".backup"
        if os.path.exists(settings_path):
            os.rename(settings_path, backup)
            print(f"  ⚠ Backed up corrupted settings to {backup}")
        settings = {}

# Remove any existing LLM Vault hooks (clean re-install)
existing_hooks = settings.get("hooks", {})
for event_name in list(existing_hooks.keys()):
    existing_hooks[event_name] = [
        group for group in existing_hooks[event_name]
        if not any(
            MARKER in h.get("command", "")
            for h in group.get("hooks", [])
        )
    ]
    if not existing_hooks[event_name]:
        del existing_hooks[event_name]

# Add LLM Vault hooks
if "hooks" not in settings:
    settings["hooks"] = {}

for event_name, hook_groups in VAULT_HOOKS.items():
    if event_name not in settings["hooks"]:
        settings["hooks"][event_name] = []
    settings["hooks"][event_name].extend(hook_groups)

# Write settings
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

print(f"  ✓ Hooks added to {settings_path}")
PYTHON_SCRIPT

# 5. Remove pause flag if it exists (enable protection)
rm -f "$VAULT_DIR/paused"

echo ""
echo "✅ LLM Vault installed successfully!"
echo ""
echo "What's active:"
echo "  • Credential paste blocking (UserPromptSubmit)"
echo "  • Leak detection in tool output (PostToolUse)"
echo "  • Secure credential instructions (SessionStart)"
echo ""
echo "Quick start:"
echo "  Store a credential:  security add-generic-password -s llm-vault -a MY_API_KEY -w"
echo "  List credentials:    python3 ~/.llm-vault/hooks/vault.py list"
echo "  Pause protection:    touch ~/.llm-vault/paused"
echo "  Resume protection:   rm ~/.llm-vault/paused"
echo "  Uninstall:           $(dirname "$0")/uninstall.sh"
