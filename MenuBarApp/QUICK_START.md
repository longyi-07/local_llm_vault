# 🚀 Quick Start: Build in 5 Minutes

## TL;DR

```bash
# 1. Open Xcode
open -a Xcode

# 2. File → New → Project → macOS App
# Name: LLMVault
# Interface: SwiftUI
# Save to: ~/Desktop/local_llm_vault/MenuBarApp/

# 3. Delete default files, add our Swift files
# 4. Add Info.plist entry: LSUIElement = YES
# 5. Press ⌘R to run
```

---

## Step-by-Step (First Time)

### 1. Create Xcode Project (2 min)

1. Open **Xcode**
2. **File** → **New** → **Project**
3. Select **macOS** → **App**
4. Settings:
   - Name: `LLMVault`
   - Interface: **SwiftUI**
   - Language: **Swift**
5. Save to: `~/Desktop/local_llm_vault/MenuBarApp/`

### 2. Add Source Files (1 min)

1. In Xcode, **delete** these default files:
   - `LLMVaultApp.swift` (we have our own)
   - `ContentView.swift`

2. **Drag all Swift files** from Finder into Xcode:
   - From: `~/Desktop/local_llm_vault/MenuBarApp/LLMVault/`
   - Drag into: Project navigator (left sidebar)
   - Check: **"Copy items if needed"**

### 3. Configure Menu Bar Mode (30 sec)

1. Click **project** (blue icon at top of navigator)
2. Select **LLMVault** target
3. Go to **Info** tab
4. Click **+** to add new entry:
   - Key: `Application is agent (UIElement)`
   - Type: Boolean
   - Value: **YES**

### 4. Build and Run (30 sec)

1. Press **⌘R** (or Product → Run)
2. Look for **🔒 lock icon** in menu bar (top-right)
3. Click it to open credential manager

**Done!** ✅

---

## Quick Commands

```bash
# Build from command line
cd ~/Desktop/local_llm_vault/MenuBarApp
xcodebuild -project LLMVault.xcodeproj -scheme LLMVault build

# Run the built app
open build/Release/LLMVault.app

# Clean build
xcodebuild clean
```

---

## What You'll See

**When it works:**

1. **Lock icon** in menu bar (top-right)
2. Click icon → **Popover appears** with:
   - Header: "🔐 LLM Vault"
   - Credentials list (empty at first)
   - + button to add credentials
   - Footer with credential count

3. **Console output:**
   ```
   ✓ LLM Vault menu bar app started
   ✓ IPC server listening on /tmp/llm-vault.sock
   ```

**Test it:**

1. Click **+** button
2. Add credential:
   - Name: `TEST_KEY`
   - Value: `hello_world`
3. Should appear in list ✅

---

## Troubleshooting

### No icon in menu bar?

→ Check Info.plist has `LSUIElement = YES`

### Build errors?

→ Make sure minimum deployment target is macOS 12.0+

### App crashes on launch?

→ Check Console.app for error messages

### Can't connect to IPC?

→ Check `/tmp/llm-vault.sock` exists:
```bash
ls -la /tmp/llm-vault.sock
```

---

## Full Instructions

See [BUILD_INSTRUCTIONS.md](BUILD_INSTRUCTIONS.md) for detailed guide.

---

**You're ready to ship! 🚀**
