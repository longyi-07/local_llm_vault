# 🔐 LLM Vault

**Stop pasting secrets into Claude. Secure credential management for AI coding assistants.**

LLM Vault prevents credential leaks to LLMs by intercepting requests, storing secrets in macOS Keychain, and automatically injecting them at runtime—without ever exposing them in conversation history.

---

## The Problem

Developers using AI coding assistants (Claude Code, GitHub Copilot, Cursor) face a dangerous pattern:

- **40% increase in secrets exposure** when using AI assistants ([2025 research](https://www.qodo.ai/reports/state-of-ai-code-quality/))
- Accidentally pasting API keys, tokens, and credentials into chat interfaces
- Credentials exposed to conversation history, server logs, and training data
- Existing tools (Gitleaks, GitGuardian) only scan commits—not AI chat interfaces

**LLM Vault solves this.**

---

## How It Works

### Reactive Detection (The Smart Way)

Instead of pattern-matching every command, LLM Vault uses **Claude's intelligence**:

```
1. User: "Deploy to AWS production"
2. Claude: Bash("aws s3 cp build/ s3://prod")
3. Tool fails: "Error: AWS_ACCESS_KEY_ID not set"
4. Claude: "Could you provide AWS_ACCESS_KEY_ID?"
5. 🔐 LLM Vault intercepts → Shows secure popup
6. User enters credential → Stored in Keychain
7. Credential auto-injected into retry
8. ✅ Success: "Deployed to s3://prod"
```

**Key insight:** We detect when Claude *asks* for credentials, not when *we guess* they're needed.

### Four-Layer Protection

1. **Prevention (UserPromptSubmit Hook)**
   - Blocks credentials pasted directly into Claude
   - Detects API keys, tokens, private keys, DB URLs
   - Shows helpful error with secure alternatives

2. **Detection (Stop Hook)**
   - Parses Claude's responses for credential requests
   - Natural language patterns: "Could you provide X?", "X not found"
   - Triggers secure credential input

3. **Injection (PreToolUse Hook)**
   - Loads cached credentials from session
   - Injects as environment variables before tool execution
   - Credentials never appear in conversation

4. **Fallback (PostToolUseFailure Hook)**
   - Catches auth failures that slip through
   - Analyzes error messages for credential issues
   - Provides helpful next steps

---

## Features

### ✅ Currently Implemented (MVP)

- **Secure Storage**: macOS Keychain integration (hardware-encrypted)
- **Session Caching**: Credentials cached per-session, cleared on exit
- **Pattern Detection**: 15+ credential patterns (OpenAI, AWS, GitHub, Stripe, etc.)
- **IPC Server**: Unix socket communication between hooks and UI
- **Terminal UI**: Prompt for credentials (temporary, until menu bar app)
- **Metadata Tracking**: Context, timestamps, auto-inject rules
- **Installation Script**: One-command setup

### 🚧 Roadmap (v2)

- **Menu Bar App** (Swift/SwiftUI): Native macOS popup for credential entry
- **1Password Integration**: Load from existing password manager
- **Bitwarden Integration**: Alternative password manager support
- **Team Vaults**: Shared credential stores for teams
- **Audit Logs**: Track when/where credentials were used
- **Cross-platform**: Linux and Windows support
- **Enterprise Features**: SSO, compliance reports, RBAC

---

## Installation

### Prerequisites

- macOS (Keychain support required)
- Claude Code installed
- Python 3.7+

### Quick Install

```bash
cd ~/Desktop/local_llm_vault
chmod +x install.sh
./install.sh
```

This will:
1. Make hooks executable
2. Install hooks into `~/.config/claude/settings.json`
3. Create credential cache directory

### Manual Installation

If you have existing Claude settings:

1. Backup your `~/.config/claude/settings.json`
2. Merge hooks from `config/claude_settings.json`
3. Replace `{{PROJECT_DIR}}` with the absolute path to `local_llm_vault`

---

## Usage

### Step 1: Start the IPC Server

In a separate terminal:

```bash
python3 ~/Desktop/local_llm_vault/lib/ipc_server.py
```

**Output:**
```
✓ LLM Vault IPC server started at /tmp/llm-vault.sock
Waiting for credential requests from Claude Code hooks...
```

Keep this running while using Claude.

### Step 2: Use Claude Code Normally

Just work as you normally would:

```
You: Deploy my app to AWS
Claude: I'll deploy using aws s3 cp...
Claude: Error: AWS_ACCESS_KEY_ID not set. Could you provide it?
🔐 LLM Vault: Detected credential request

   Enter value for AWS_ACCESS_KEY_ID: ********
   ✓ Stored in keychain

✓ AWS_ACCESS_KEY_ID loaded from secure storage.
You can now retry the command.

You: Try again
Claude: [Credential auto-injected] ✅ Deployed!
```

### Step 3: Try Pasting a Credential (It Will Be Blocked)

```
You: Here's my API key: sk-abc123...
🚨 LLM Vault: Credential Leak Prevention

Detected 1 potential credential(s):
- OpenAI API Key: sk-abc***123

Your message was NOT sent to Claude.
```

---

## Architecture

### Project Structure

```
local_llm_vault/
├── README.md              # This file
├── install.sh             # Installation script
├── hooks/                 # Claude Code hooks
│   ├── stop_hook.py                    # Detect Claude asking for credentials
│   ├── pretooluse_hook.py              # Inject cached credentials
│   ├── userpromptsubmit_hook.py        # Block pasted credentials
│   └── posttoolusefailure_hook.py      # Detect auth errors
├── lib/                   # Core libraries
│   ├── credential_manager.py           # Keychain interface
│   └── ipc_server.py                   # IPC server + client
├── config/                # Configuration
│   └── claude_settings.json            # Claude Code hooks config
└── tests/                 # Test suite
    └── (coming soon)
```

### Data Flow

```
┌─────────────────────────────────────────────────────┐
│ User types in Claude Code                           │
└─────────────────┬───────────────────────────────────┘
                  │
                  v
┌─────────────────────────────────────────────────────┐
│ UserPromptSubmit Hook                               │
│ ❌ Blocks if credentials detected in paste         │
└─────────────────┬───────────────────────────────────┘
                  │ (if allowed)
                  v
┌─────────────────────────────────────────────────────┐
│ Claude processes and generates tool call           │
└─────────────────┬───────────────────────────────────┘
                  │
                  v
┌─────────────────────────────────────────────────────┐
│ PreToolUse Hook                                     │
│ ✓ Injects cached credentials from session          │
└─────────────────┬───────────────────────────────────┘
                  │
                  v
┌─────────────────────────────────────────────────────┐
│ Tool executes (Bash, Read, etc.)                   │
└─────────────────┬───────────────────────────────────┘
                  │
                  ├─ Success → Continue
                  │
                  └─ Failure → PostToolUseFailure Hook
                              │ ❓ Auth error?
                              └─ Add helpful context
                  │
                  v
┌─────────────────────────────────────────────────────┐
│ Claude responds to user                             │
└─────────────────┬───────────────────────────────────┘
                  │
                  v
┌─────────────────────────────────────────────────────┐
│ Stop Hook                                           │
│ 🔍 Detects "Could you provide X?" in response      │
│ 📞 Calls IPC server → Prompts user                 │
│ 💾 Stores in Keychain + session cache              │
└─────────────────────────────────────────────────────┘
```

### Storage

**Session Cache** (temporary, per Claude session):
```
/tmp/llm-vault-session-{session_id}.json
```
- Cleared when Claude exits
- Fast lookup (no Keychain query per command)
- Contains: credential values, context, timestamps

**Keychain** (permanent, encrypted):
```
Service: local-llm-vault
Account: {CREDENTIAL_NAME}
Password: {SECRET_VALUE}
```
- Hardware-encrypted by macOS
- Accessible only to your user account
- Syncs across devices with iCloud Keychain (if enabled)

**Metadata** (for audit and auto-inject rules):
```
~/.local-llm-vault/{CREDENTIAL_NAME}.meta.json
```
- Source (user_input, keychain, etc.)
- Context (what command requested it)
- Timestamps (created, last used)
- Auto-inject rules

---

## Security Model

### What LLM Vault Protects

✅ Prevents credentials in conversation history
✅ Prevents credentials in Anthropic server logs
✅ Prevents accidental pastes into chat
✅ Credentials encrypted by hardware (Keychain)
✅ Session-scoped caching (cleared on exit)
✅ Audit trail of credential usage

### What LLM Vault Does NOT Protect

❌ Malicious code generated by Claude (always review code!)
❌ Credentials already committed to git (use Gitleaks)
❌ Screen recordings showing credentials
❌ Keyloggers or system compromises

### Threat Model

**Threats mitigated:**
- Accidental credential exposure to LLM provider
- Conversation history containing secrets
- Training data contamination
- Log file leaks

**Threats NOT mitigated:**
- Compromised macOS account (Keychain is accessible)
- Malicious Claude-generated code exfiltrating credentials
- Social engineering attacks

**Recommended practices:**
- Always review code Claude generates
- Use separate credentials for AI-assisted development
- Rotate credentials regularly
- Enable 2FA on all services

---

## Development

### Testing Hooks Manually

Test credential detection:
```bash
echo '{"assistant_message": "Could you provide the AWS_ACCESS_KEY_ID?"}' | \
  python3 hooks/stop_hook.py
```

Test credential blocking:
```bash
echo '{"user_message": "My API key is sk-abc123..."}' | \
  python3 hooks/userpromptsubmit_hook.py
```

### Testing Credential Manager

```bash
python3 lib/credential_manager.py
```

This runs a self-test that stores, retrieves, and deletes a test credential.

### Adding New Credential Patterns

Edit `hooks/userpromptsubmit_hook.py` and add to `CREDENTIAL_PATTERNS`:

```python
(r'your_pattern_here', 'Credential Type Name'),
```

### Debugging

Hooks log to stderr, which appears in the Claude Code terminal:

```bash
export DEBUG=1
claude
```

---

## Comparison

| Solution | Scope | Prevention | Detection | Injection |
|----------|-------|------------|-----------|-----------|
| **LLM Vault** | AI chat interfaces | ✅ Blocks paste | ✅ Claude asks | ✅ Auto-inject |
| Gitleaks | Git commits | ❌ Post-commit | ✅ Scans history | ❌ N/A |
| GitGuardian | GitHub repos | ❌ Post-push | ✅ SaaS scanning | ❌ N/A |
| Microsoft Purview | M365 Copilot | ✅ Blocks prompts | ✅ DLP rules | ❌ N/A |
| 1Password | Manual | ❌ No integration | ❌ Manual | ❌ Manual |

**LLM Vault is the only open-source solution for CLI AI assistants.**

---

## FAQ

### Why not just use environment variables?

Environment variables work, but:
- They're still in plain text on disk (`.env` files)
- They're visible in `ps aux` output
- They don't prevent accidental pastes into chat
- No audit trail of usage

LLM Vault uses Keychain (encrypted) and prevents conversation exposure.

### Does this work with GitHub Copilot / Cursor?

**Not yet.** LLM Vault currently only supports Claude Code hooks. However:
- GitHub Copilot CLI support is planned (v2)
- Cursor support is planned (v2)
- The architecture is extensible to other AI tools

### What if I need to share credentials with my team?

MVP is single-user only. Team vaults are planned for v2:
- Shared Keychain access
- Role-based access control (RBAC)
- Audit logs for compliance
- SSO integration

### Can I use this for free?

**Yes!** LLM Vault is MIT licensed and fully open source. The roadmap includes:
- **Free tier**: Individual developers, basic features
- **Pro tier** ($10/mo): 1Password integration, audit logs
- **Enterprise** ($39/seat): Team vaults, SSO, compliance reports

### How do I uninstall?

```bash
# Remove hooks from Claude settings
# Edit ~/.config/claude/settings.json and remove LLM Vault hooks

# Remove credentials from Keychain
security delete-generic-password -s local-llm-vault -a CREDENTIAL_NAME

# Remove project
rm -rf ~/Desktop/local_llm_vault
rm -rf ~/.local-llm-vault
```

---

## Contributing

This is a **brand new project** (launched February 2026). We welcome contributions!

### Priority Areas

- **Menu bar app** (Swift/SwiftUI)
- **Linux support** (libsecret instead of Keychain)
- **Windows support** (Credential Manager)
- **Test suite** (pytest)
- **1Password integration** (op CLI)
- **Documentation** (video tutorials, blog posts)

### How to Contribute

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/menu-bar-app`
3. Commit changes: `git commit -am 'Add menu bar app'`
4. Push: `git push origin feature/menu-bar-app`
5. Submit a pull request

---

## License

MIT License - see LICENSE file

---

## Credits

**Created by:** [Your Name] (CTO, [Your Startup])

**Inspired by:**
- The 40% increase in secrets exposure when using AI assistants
- Lack of open-source solutions for CLI AI tools
- Claude Code's powerful hooks system

**Special thanks to:**
- Anthropic for building Claude Code
- The open-source security community
- Early testers and contributors

---

## Contact

- **GitHub**: [coming soon]
- **Twitter**: [coming soon]
- **Email**: [coming soon]
- **Discord**: [coming soon]

---

## Changelog

### v0.1.0 (2026-02-04) - MVP Launch

- ✅ Four-layer protection (Prevention, Detection, Injection, Fallback)
- ✅ macOS Keychain integration
- ✅ Session caching
- ✅ 15+ credential patterns
- ✅ IPC server + terminal UI
- ✅ Installation script
- ✅ Comprehensive documentation

### Roadmap

**v0.2.0** - Menu Bar App
- Swift/SwiftUI native app
- Native popups for credential entry
- System tray integration

**v0.3.0** - Cross-platform
- Linux support (libsecret)
- Windows support (Credential Manager)

**v1.0.0** - Production Ready
- 1Password/Bitwarden integration
- Team vaults
- Audit logs
- Enterprise features

---

**Stop pasting secrets into Claude. Use LLM Vault.**

🔐 **[Install Now](#installation)** | 📚 **[Read Docs](#how-it-works)** | 🐛 **[Report Issues](https://github.com/...)**
