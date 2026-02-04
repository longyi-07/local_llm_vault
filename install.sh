#!/bin/bash
# LLM Vault - Installation Script
# Installs hooks into Claude Code configuration

set -e

echo "🔐 LLM Vault - Installation"
echo "================================"
echo ""

# Get the absolute path to this script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Claude Code settings directory
CLAUDE_SETTINGS_DIR="$HOME/.config/claude"
CLAUDE_SETTINGS_FILE="$CLAUDE_SETTINGS_DIR/settings.json"

# Make hooks executable
echo "📝 Making hooks executable..."
chmod +x "$SCRIPT_DIR/hooks"/*.py
chmod +x "$SCRIPT_DIR/lib"/*.py

# Create Claude settings directory if it doesn't exist
if [ ! -d "$CLAUDE_SETTINGS_DIR" ]; then
    echo "📁 Creating Claude settings directory..."
    mkdir -p "$CLAUDE_SETTINGS_DIR"
fi

# Check if settings.json exists
if [ -f "$CLAUDE_SETTINGS_FILE" ]; then
    echo "⚠️  Claude settings file already exists"
    echo "   Location: $CLAUDE_SETTINGS_FILE"
    echo ""
    echo "   You have two options:"
    echo "   1. Backup and replace (recommended for first install)"
    echo "   2. Manually merge hooks from config/claude_settings.json"
    echo ""
    read -p "   Backup and replace? (y/N): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Backup existing settings
        BACKUP_FILE="$CLAUDE_SETTINGS_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        echo "💾 Backing up existing settings to:"
        echo "   $BACKUP_FILE"
        cp "$CLAUDE_SETTINGS_FILE" "$BACKUP_FILE"

        # Replace PROJECT_DIR placeholder
        sed "s|{{PROJECT_DIR}}|$SCRIPT_DIR|g" "$SCRIPT_DIR/config/claude_settings.json" > "$CLAUDE_SETTINGS_FILE"

        echo "✓ Settings installed"
    else
        echo ""
        echo "📝 Manual installation required:"
        echo "   1. Open: $CLAUDE_SETTINGS_FILE"
        echo "   2. Merge hooks from: $SCRIPT_DIR/config/claude_settings.json"
        echo "   3. Replace {{PROJECT_DIR}} with: $SCRIPT_DIR"
        echo ""
        exit 0
    fi
else
    # No existing settings, install fresh
    echo "📝 Installing Claude settings..."

    # Replace PROJECT_DIR placeholder
    sed "s|{{PROJECT_DIR}}|$SCRIPT_DIR|g" "$SCRIPT_DIR/config/claude_settings.json" > "$CLAUDE_SETTINGS_FILE"

    echo "✓ Settings installed"
fi

echo ""
echo "================================"
echo "✓ LLM Vault installed successfully!"
echo ""
echo "📚 Next steps:"
echo ""
echo "1. Start the IPC server (in a separate terminal):"
echo "   python3 $SCRIPT_DIR/lib/ipc_server.py"
echo ""
echo "2. Open Claude Code and try it:"
echo "   - Type: 'Deploy to AWS' or run a command that needs credentials"
echo "   - Claude will detect missing credentials"
echo "   - LLM Vault will prompt you securely"
echo ""
echo "3. Try pasting a credential directly:"
echo "   - LLM Vault will block it and show a warning"
echo ""
echo "4. Read the full docs:"
echo "   cat $SCRIPT_DIR/README.md"
echo ""
echo "🔒 Your credentials are stored in macOS Keychain"
echo "   Never in plain text, never in conversation history"
echo ""
