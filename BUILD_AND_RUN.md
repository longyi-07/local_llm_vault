# 🚀 Complete Build & Run Guide

## Two Options to Run LLM Vault

### Option A: Menu Bar App (Native macOS) - **Recommended**

The beautiful native app with menu bar icon and popups.

**Quick Start:**
```bash
# 1. Open the Quick Start guide
open ~/Desktop/local_llm_vault/MenuBarApp/QUICK_START.md

# 2. Follow 5-minute guide to build in Xcode
```

**Or see full instructions:**
```bash
open ~/Desktop/local_llm_vault/MenuBarApp/BUILD_INSTRUCTIONS.md
```

---

### Option B: Terminal-Based (Python IPC Server)

Works immediately without building anything.

**Start the server:**
```bash
cd ~/Desktop/local_llm_vault
python3 lib/ipc_server.py
```

**What you'll see:**
```
✓ LLM Vault IPC server started at /tmp/llm-vault.sock
Waiting for credential requests from Claude Code hooks...
```

Keep this running in a terminal tab.

---

## Recommended Setup

**Best experience:** Use both together!

1. **Build and run the menu bar app** (follow QUICK_START.md)
   - Native macOS popups for credential input
   - Visual credential manager
   - System tray icon

2. **The menu bar app starts its own IPC server**
   - No need to run `python3 lib/ipc_server.py` separately
   - Everything integrated

---

## Testing After Build

### 1. Install Claude Hooks

```bash
cd ~/Desktop/local_llm_vault
./install.sh
```

### 2. Test Prevention (Paste Detection)

Open Claude Code and type:
```
My API key is sk-abc123def456
```

**Expected:** Blocked with helpful error ✅

### 3. Test Reactive Detection

In Claude Code:
```
Deploy to AWS
```

When Claude responds with "Could you provide AWS_ACCESS_KEY_ID?":

**With Menu Bar App:**
- Native dialog appears
- Enter credential
- Stored in Keychain
- Auto-injected on retry

**With Terminal Server:**
- Prompt appears in terminal
- Enter credential
- Same behavior

### 4. Test Auto-Injection

After adding a credential, run any command that needs it:
```
Run: aws s3 ls
```

**Expected:** Credential auto-injected, command succeeds ✅

---

## Architecture

```
┌─────────────────────────────────────────┐
│  Menu Bar App (Swift)                   │
│  - Shows in top-right of screen        │
│  - Native dialogs                       │
│  - IPC server built-in                  │
└─────────┬───────────────────────────────┘
          │
          v
┌─────────────────────────────────────────┐
│  Unix Socket: /tmp/llm-vault.sock       │
└─────────┬───────────────────────────────┘
          │
          v
┌─────────────────────────────────────────┐
│  Claude Code Hooks (Python)             │
│  - Stop Hook (detect requests)          │
│  - PreToolUse Hook (inject creds)       │
│  - UserPromptSubmit Hook (block paste)  │
│  - PostToolUseFailure Hook (errors)     │
└─────────┬───────────────────────────────┘
          │
          v
┌─────────────────────────────────────────┐
│  macOS Keychain (Secure Storage)        │
│  - Hardware encrypted                   │
│  - Accessible only to your user         │
└─────────────────────────────────────────┘
```

---

## Quick Comparison

| Feature | Menu Bar App | Terminal Server |
|---------|--------------|-----------------|
| Setup | Build with Xcode (5 min) | Instant (Python) |
| UI | Native dialogs | Terminal prompts |
| Convenience | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Visual | Menu bar icon | None |
| Auto-launch | Yes (can set) | Manual |
| Distribution | App bundle | Python script |

**Recommendation:** Build the menu bar app for best UX.

---

## Troubleshooting

### Issue: Hooks not running

**Check:**
```bash
cat ~/.config/claude/settings.json
```

Should see LLM Vault hooks configured.

**Fix:**
```bash
cd ~/Desktop/local_llm_vault
./install.sh
```

### Issue: IPC connection fails

**Check socket:**
```bash
ls -la /tmp/llm-vault.sock
```

**Fix:** Make sure menu bar app or Python server is running.

### Issue: Credentials not saving

**Check Keychain access:**
```bash
security find-generic-password -s local-llm-vault
```

**Fix:** Make sure app has Keychain access (should prompt on first use).

### Issue: Menu bar icon not appearing

**Check Info.plist:**
Must have `LSUIElement = YES` to run as menu bar app.

---

## Development Workflow

**Daily usage:**

1. Launch menu bar app (auto-starts IPC server)
2. Use Claude Code normally
3. When credentials needed, dialog appears
4. Enter once, used forever (until you delete)

**Making changes:**

1. Edit Swift files in Xcode
2. Press ⌘R to rebuild
3. App updates automatically

**Updating hooks:**

1. Edit Python hooks in `hooks/` directory
2. No rebuild needed (hooks are scripts)
3. Changes take effect on next Claude session

---

## Next Steps

1. **Build the menu bar app** (5 minutes)
   - Follow: `MenuBarApp/QUICK_START.md`

2. **Test all features** (10 minutes)
   - Credential prevention
   - Reactive detection
   - Auto-injection

3. **Use it daily!**
   - Keep menu bar app running
   - Your credentials are protected
   - No more paste accidents

4. **Ship it!** (when ready)
   - Create GitHub repo
   - Share on Product Hunt
   - Get feedback from users

---

**You're ready to build! Let's go! 🚀**

Open the Quick Start guide:
```bash
open ~/Desktop/local_llm_vault/MenuBarApp/QUICK_START.md
```
