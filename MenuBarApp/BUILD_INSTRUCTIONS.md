# 🛠 Building the LLM Vault Menu Bar App

## Prerequisites

- macOS 12.0 or later
- Xcode 14.0 or later
- Swift 5.7+

---

## Option 1: Build with Xcode (Recommended)

### Step 1: Create Xcode Project

1. Open **Xcode**
2. File → New → Project
3. Select **macOS** → **App**
4. Click **Next**

**Project Settings:**
- Product Name: `LLMVault`
- Team: Your Apple Developer team (or None for local development)
- Organization Identifier: `com.yourdomain` (or whatever you want)
- Interface: **SwiftUI**
- Language: **Swift**
- Click **Next**

**Save Location:**
- Navigate to: `~/Desktop/local_llm_vault/MenuBarApp/`
- Click **Create**

### Step 2: Add Source Files

1. In Xcode, **delete** the default `LLMVaultApp.swift` and `ContentView.swift` files
2. Right-click on the `LLMVault` folder in the project navigator
3. Select **Add Files to "LLMVault"...**
4. Navigate to `~/Desktop/local_llm_vault/MenuBarApp/LLMVault/`
5. Select **all 6 Swift files**:
   - LLMVaultApp.swift
   - MenuBarView.swift
   - CredentialInputDialog.swift
   - KeychainManager.swift
   - IPCServer.swift
   - SettingsView.swift
6. Make sure **"Copy items if needed"** is checked
7. Click **Add**

### Step 3: Configure Project Settings

1. Select the **project** (blue icon) in the navigator
2. Select the **LLMVault target**
3. Go to **Signing & Capabilities** tab
4. If you have an Apple Developer account:
   - Select your **Team**
5. If you don't have a developer account:
   - Uncheck **"Automatically manage signing"**
   - Set **Signing Certificate** to "Sign to Run Locally"

### Step 4: Configure Menu Bar App

1. In **General** tab:
   - Minimum Deployments: **macOS 12.0**

2. In **Info** tab (or open Info.plist):
   - Add new entry:
     - Key: `Application is agent (UIElement)` → Value: `YES`
     - This makes the app run as a menu bar app only (no Dock icon)

3. **Optional**: Add app icon
   - Assets.xcassets → AppIcon
   - Drag your icon files (or leave default)

### Step 5: Build and Run

1. Select **Product** → **Run** (or press `⌘R`)
2. The app should compile and launch
3. Look for the **lock shield icon** in your menu bar (top-right)
4. Click it to see the credential manager popover

**Expected output in Console:**
```
✓ LLM Vault menu bar app started
✓ IPC server listening on /tmp/llm-vault.sock
```

---

## Option 2: Build from Command Line

If you prefer command-line builds:

### Step 1: Create Xcode Project (one-time)

Follow **Option 1, Steps 1-4** to create the initial project with Xcode GUI.

### Step 2: Build from Terminal

```bash
cd ~/Desktop/local_llm_vault/MenuBarApp

# Build the app
xcodebuild -project LLMVault.xcodeproj \
  -scheme LLMVault \
  -configuration Release \
  build
```

### Step 3: Run the App

```bash
# Find the built app
open ~/Desktop/local_llm_vault/MenuBarApp/build/Release/LLMVault.app
```

---

## Option 3: Quick Script Build (Advanced)

I've created a script that automates the Xcode project setup:

```bash
cd ~/Desktop/local_llm_vault/MenuBarApp
chmod +x create_xcode_project.sh
./create_xcode_project.sh
```

Then open the generated project:

```bash
open LLMVault.xcodeproj
```

---

## Troubleshooting

### Issue: "Could not find or use auto-linked library"

**Solution:** Make sure you're building for macOS 12.0+
1. Project Settings → General → Minimum Deployments → **macOS 12.0**

### Issue: App doesn't appear in menu bar

**Solution:** Check Info.plist has `Application is agent (UIElement) = YES`

1. Open Info.plist
2. Add key: `LSUIElement` with value `YES` (boolean)

### Issue: "Untrusted Developer" warning

**Solution:**
```bash
# Allow the app to run
xattr -cr ~/Desktop/local_llm_vault/MenuBarApp/build/Release/LLMVault.app
```

### Issue: IPC socket connection fails

**Solution:** Make sure the Python hooks can reach `/tmp/llm-vault.sock`

Check permissions:
```bash
ls -la /tmp/llm-vault.sock
# Should show: srw------- (socket, user read/write only)
```

---

## Testing the Integration

### Test 1: Launch Menu Bar App

1. Build and run from Xcode
2. Check menu bar for lock icon
3. Click icon → Should show credential manager

### Test 2: Test IPC Communication

In Terminal:
```bash
# Send test request
echo '{"action":"list_credentials"}' | nc -U /tmp/llm-vault.sock
```

Expected response:
```json
{"status":"ok","credentials":[]}
```

### Test 3: Add Credential via UI

1. Click menu bar icon
2. Click **+** button
3. Enter:
   - Name: `TEST_KEY`
   - Value: `test_value_123`
4. Click **Add**
5. Credential should appear in list

### Test 4: Test with Claude Code Hooks

1. Keep menu bar app running
2. Open Claude Code
3. Type: "Show me my AWS credentials"
4. When Claude asks for `AWS_ACCESS_KEY_ID`:
   - Menu bar app should show a dialog
   - Enter a test value
   - Should appear in Claude's next command

---

## Building for Distribution

### Create Release Build

```bash
xcodebuild -project LLMVault.xcodeproj \
  -scheme LLMVault \
  -configuration Release \
  -archivePath ./build/LLMVault.xcarchive \
  archive

# Export app
xcodebuild -exportArchive \
  -archivePath ./build/LLMVault.xcarchive \
  -exportPath ./build/Release \
  -exportOptionsPlist ExportOptions.plist
```

### Code Signing (for distribution)

If you want to distribute the app:

1. Get an Apple Developer account ($99/year)
2. Create a Developer ID Application certificate
3. Sign the app:

```bash
codesign --force --deep --sign "Developer ID Application: Your Name" \
  LLMVault.app
```

### Notarize (for distribution outside Mac App Store)

```bash
# Create zip
ditto -c -k --keepParent LLMVault.app LLMVault.zip

# Submit for notarization
xcrun notarytool submit LLMVault.zip \
  --apple-id your@email.com \
  --team-id TEAMID \
  --password app-specific-password

# Staple notarization ticket
xcrun stapler staple LLMVault.app
```

---

## Auto-Launch on Login (Optional)

To make the app start automatically when you log in:

1. Open **System Settings** → **General** → **Login Items**
2. Click **+** button
3. Select `LLMVault.app`
4. App will now launch on login

---

## Development Tips

### Live Preview in Xcode

SwiftUI views support live previews:

1. Open any `.swift` file with a `View`
2. Click **Resume** in the Canvas panel (right side)
3. See live preview as you edit

### Debug IPC Communication

Add breakpoints in `IPCServer.swift`:
- Line where `handleClient()` is called
- Line where credentials are requested

Run with debugger (`⌘R`) to step through IPC requests.

### Hot Reload

To rebuild without restarting:
1. Make code changes
2. Press `⌘B` to build
3. Xcode will hot-reload if possible

---

## Next Steps

Once the app is built and running:

1. **Install Claude hooks**: Run `./install.sh` from main project directory
2. **Test the full flow**: Use Claude Code to trigger credential requests
3. **Customize the UI**: Edit SwiftUI files to match your branding
4. **Add features**: See roadmap in main README.md

---

## Getting Help

- **Xcode Issues**: Check [Apple Developer Forums](https://developer.apple.com/forums/)
- **Swift Questions**: [Swift Forums](https://forums.swift.org/)
- **Project Issues**: Open an issue on GitHub

---

**Built with ❤️ in Swift and SwiftUI**
