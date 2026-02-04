# 🚀 LLM Vault - Quick Start Guide

Get up and running in 5 minutes.

---

## Step 1: Install (1 minute)

```bash
cd ~/Desktop/local_llm_vault
chmod +x install.sh
./install.sh
```

**What this does:**
- Makes hooks executable
- Installs into `~/.config/claude/settings.json`
- Creates cache directory

---

## Step 2: Start the Server (30 seconds)

Open a new terminal and run:

```bash
cd ~/Desktop/local_llm_vault
python3 lib/ipc_server.py
```

**Keep this running while using Claude.**

---

## Step 3: Test It! (3 minutes)

### Test 1: Credential Prevention

Open Claude Code and type:

```
My OpenAI API key is sk-abc123def456
```

**Expected result:**
```
🚨 LLM Vault: Credential Leak Prevention

Detected 1 potential credential(s):
- OpenAI API Key: sk-abc***456

Your message was NOT sent to Claude.
```

✅ **Success!** LLM Vault blocked the credential.

---

### Test 2: Reactive Detection

In Claude Code, type:

```
Show me my AWS credentials
```

Claude might respond with something like:
```
Could you provide the AWS_ACCESS_KEY_ID environment variable?
```

**Expected result in server terminal:**
```
🔐 LLM Vault: Detected credential request
   Enter value for AWS_ACCESS_KEY_ID: _____
```

Enter a test value (e.g., `AKIA_TEST_123456`).

**Expected result in Claude:**
```
✓ LLM Vault: Loaded AWS_ACCESS_KEY_ID from secure storage.
You can now retry the command.
```

✅ **Success!** Credential was stored and cached.

---

### Test 3: Auto-Injection

In Claude Code, type:

```
Run the command: echo "AWS Key: $AWS_ACCESS_KEY_ID"
```

**Expected result in server terminal:**
```
🔐 LLM Vault: Injecting 1 credential(s)
   - AWS_ACCESS_KEY_ID
```

**Expected result in Claude:**
```
AWS Key: AKIA_TEST_123456
```

✅ **Success!** Credential was auto-injected!

---

## Step 4: Manage Credentials (Optional)

Make the CLI executable:

```bash
chmod +x ~/Desktop/local_llm_vault/vault-cli.py
```

Then use it:

```bash
# List all credentials
python3 ~/Desktop/local_llm_vault/vault-cli.py list

# Add a credential manually
python3 ~/Desktop/local_llm_vault/vault-cli.py add GITHUB_TOKEN

# Delete a test credential
python3 ~/Desktop/local_llm_vault/vault-cli.py delete AWS_ACCESS_KEY_ID -f
```

---

## What's Next?

### Read the Full Docs

```bash
cat ~/Desktop/local_llm_vault/README.md
```

### Try Real Use Cases

1. **Deploy to AWS:**
   ```
   You: Deploy my site to AWS S3
   Claude: [Detects missing AWS creds] Could you provide...
   LLM Vault: [Prompts securely]
   Claude: [Auto-injects and deploys] ✅
   ```

2. **Push to GitHub:**
   ```
   You: Create a PR for this branch
   Claude: [Needs GITHUB_TOKEN]
   LLM Vault: [Handles it]
   ```

3. **Run Terraform:**
   ```
   You: Apply the terraform changes
   Claude: [Needs cloud credentials]
   LLM Vault: [Injects automatically]
   ```

---

## Troubleshooting

### Hooks not running?

Check Claude settings:
```bash
cat ~/.config/claude/settings.json
```

Should see LLM Vault hooks configured.

### Server not responding?

Check if running:
```bash
ls -la /tmp/llm-vault.sock
```

Should show the Unix socket file.

### Credentials not injecting?

Check session cache:
```bash
ls -la /tmp/llm-vault-session-*.json
```

Should show cached credentials for your session.

---

## Need Help?

- **Full Documentation**: `README.md`
- **Architecture**: See "Architecture" section in README
- **Security Model**: See "Security Model" section in README

---

**🔐 You're all set! Your credentials are now protected.**

Stop pasting secrets into Claude. Use LLM Vault.
