#!/bin/bash
set +e

# LLM Vault — Validation Suite
# Tests all hooks, install/uninstall, and pause mechanism

HOOKS_DIR="$HOME/.llm-vault/hooks"
VAULT_DIR="$HOME/.llm-vault"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
PASS=0
FAIL=0

green()  { printf "\033[32m%s\033[0m\n" "$1"; }
red()    { printf "\033[31m%s\033[0m\n" "$1"; }
header() { printf "\n\033[1m━━━ %s ━━━\033[0m\n" "$1"; }

assert_exit() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        green "  ✓ $desc"
        PASS=$((PASS + 1))
    else
        red "  ✗ $desc (expected exit $expected, got $actual)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -q "$needle"; then
        green "  ✓ $desc"
        PASS=$((PASS + 1))
    else
        red "  ✗ $desc (expected output to contain: $needle)"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -q "$needle"; then
        red "  ✗ $desc (output should NOT contain: $needle)"
        FAIL=$((FAIL + 1))
    else
        green "  ✓ $desc"
        PASS=$((PASS + 1))
    fi
}

assert_file_exists() {
    local desc="$1" path="$2"
    if [ -e "$path" ]; then
        green "  ✓ $desc"
        PASS=$((PASS + 1))
    else
        red "  ✗ $desc ($path not found)"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
header "1. Install"
# ============================================================

# Clean state for testing
cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.test-backup" 2>/dev/null || true

bash "$(dirname "$0")/install.sh" > /dev/null 2>&1

assert_file_exists "hooks/block_secrets.py installed" "$HOOKS_DIR/block_secrets.py"
assert_file_exists "hooks/check_leaks.py installed"   "$HOOKS_DIR/check_leaks.py"
assert_file_exists "hooks/session_start.py installed"  "$HOOKS_DIR/session_start.py"
assert_file_exists "hooks/vault.py installed"          "$HOOKS_DIR/vault.py"
assert_file_exists "credential registry created"       "$VAULT_DIR/keys.json"

# Verify settings.json has the hooks
SETTINGS_CONTENT=$(cat "$CLAUDE_SETTINGS")
assert_contains "settings has SessionStart hook"      "$SETTINGS_CONTENT" "session_start.py"
assert_contains "settings has UserPromptSubmit hook"   "$SETTINGS_CONTENT" "block_secrets.py"
assert_contains "settings has PostToolUse hook"        "$SETTINGS_CONTENT" "check_leaks.py"

# ============================================================
header "2. Idempotent re-install"
# ============================================================

bash "$(dirname "$0")/install.sh" > /dev/null 2>&1

# Count hook entries — should be exactly 1 each
SESSION_COUNT=$(python3 -c "import json; s=json.load(open('$CLAUDE_SETTINGS')); print(len(s.get('hooks',{}).get('SessionStart',[])))")
PROMPT_COUNT=$(python3 -c "import json; s=json.load(open('$CLAUDE_SETTINGS')); print(len(s.get('hooks',{}).get('UserPromptSubmit',[])))")
POST_COUNT=$(python3 -c "import json; s=json.load(open('$CLAUDE_SETTINGS')); print(len(s.get('hooks',{}).get('PostToolUse',[])))")

assert_exit "SessionStart: 1 group after re-install"    "1" "$SESSION_COUNT"
assert_exit "UserPromptSubmit: 1 group after re-install" "1" "$PROMPT_COUNT"
assert_exit "PostToolUse: 1 group after re-install"      "1" "$POST_COUNT"

# ============================================================
header "3. UserPromptSubmit — block_secrets.py"
# ============================================================

# Should block: OpenAI key
OUTPUT=$(echo '{"prompt": "use this key sk-proj-abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG"}' \
    | python3 "$HOOKS_DIR/block_secrets.py" 2>&1); EXIT=$?
assert_exit "blocks OpenAI project key" "2" "$EXIT"
assert_contains "mentions OpenAI" "$OUTPUT" "OpenAI"

# Should block: AWS access key
OUTPUT=$(echo '{"prompt": "my aws key is AKIAIOSFODNN7EXAMPLE"}' \
    | python3 "$HOOKS_DIR/block_secrets.py" 2>&1); EXIT=$?
assert_exit "blocks AWS access key" "2" "$EXIT"
assert_contains "mentions AWS" "$OUTPUT" "AWS"

# Should block: GitHub PAT
OUTPUT=$(echo '{"prompt": "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijkl"}' \
    | python3 "$HOOKS_DIR/block_secrets.py" 2>&1); EXIT=$?
assert_exit "blocks GitHub PAT" "2" "$EXIT"

# Should block: Anthropic key
OUTPUT=$(echo '{"prompt": "sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJ"}' \
    | python3 "$HOOKS_DIR/block_secrets.py" 2>&1); EXIT=$?
assert_exit "blocks Anthropic key" "2" "$EXIT"

# Should block: private key
OUTPUT=$(echo '{"prompt": "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQ"}' \
    | python3 "$HOOKS_DIR/block_secrets.py" 2>&1); EXIT=$?
assert_exit "blocks private key" "2" "$EXIT"

# Should block: database URL with password
OUTPUT=$(echo '{"prompt": "postgres://admin:s3cret@db.example.com:5432/mydb"}' \
    | python3 "$HOOKS_DIR/block_secrets.py" 2>&1); EXIT=$?
assert_exit "blocks database URL with password" "2" "$EXIT"

# Should block: SendGrid key
OUTPUT=$(echo '{"prompt": "SG.abcdefghijklmnopqrstuvw.ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrs"}' \
    | python3 "$HOOKS_DIR/block_secrets.py" 2>&1); EXIT=$?
assert_exit "blocks SendGrid API key" "2" "$EXIT"

# Should allow: normal prompts
OUTPUT=$(echo '{"prompt": "deploy my app to production"}' \
    | python3 "$HOOKS_DIR/block_secrets.py" 2>&1); EXIT=$?
assert_exit "allows normal prompt" "0" "$EXIT"

# Should allow: code with no secrets
OUTPUT=$(echo '{"prompt": "def hello():\n    return \"world\""}' \
    | python3 "$HOOKS_DIR/block_secrets.py" 2>&1); EXIT=$?
assert_exit "allows code without secrets" "0" "$EXIT"

# Should allow: empty prompt
OUTPUT=$(echo '{"prompt": ""}' \
    | python3 "$HOOKS_DIR/block_secrets.py" 2>&1); EXIT=$?
assert_exit "allows empty prompt" "0" "$EXIT"

# Should allow: mentions key names without values
OUTPUT=$(echo '{"prompt": "set AWS_ACCESS_KEY_ID as an environment variable"}' \
    | python3 "$HOOKS_DIR/block_secrets.py" 2>&1); EXIT=$?
assert_exit "allows mentioning key names" "0" "$EXIT"

# ============================================================
header "4. PostToolUse — check_leaks.py"
# ============================================================

# Store a test credential
security delete-generic-password -s llm-vault -a TEST_LEAK_KEY 2>/dev/null || true
security add-generic-password -s llm-vault -a TEST_LEAK_KEY -w "supersecretvalue12345" -U 2>/dev/null

# Register it
python3 -c "
import json, os
path = os.path.expanduser('~/.llm-vault/keys.json')
keys = json.load(open(path))
if 'TEST_LEAK_KEY' not in keys:
    keys.append('TEST_LEAK_KEY')
    json.dump(keys, open(path, 'w'))
"

# Should detect: credential value in tool output
OUTPUT=$(echo '{"tool_name": "Bash", "tool_input": {"command": "echo test"}, "tool_response": "the output is supersecretvalue12345 here"}' \
    | python3 "$HOOKS_DIR/check_leaks.py" 2>&1); EXIT=$?
assert_exit "detects leaked credential in output" "0" "$EXIT"
assert_contains "warns about TEST_LEAK_KEY" "$OUTPUT" "TEST_LEAK_KEY"
assert_contains "returns block decision" "$OUTPUT" "block"

# Should allow: clean output
OUTPUT=$(echo '{"tool_name": "Bash", "tool_input": {"command": "ls"}, "tool_response": "file1.txt file2.txt"}' \
    | python3 "$HOOKS_DIR/check_leaks.py" 2>&1); EXIT=$?
assert_exit "allows clean tool output" "0" "$EXIT"
assert_not_contains "no block on clean output" "$OUTPUT" "block"

# Should allow: empty response
OUTPUT=$(echo '{"tool_name": "Bash", "tool_input": {"command": "true"}, "tool_response": ""}' \
    | python3 "$HOOKS_DIR/check_leaks.py" 2>&1); EXIT=$?
assert_exit "allows empty tool output" "0" "$EXIT"

# Cleanup test credential
security delete-generic-password -s llm-vault -a TEST_LEAK_KEY 2>/dev/null || true
python3 -c "
import json, os
path = os.path.expanduser('~/.llm-vault/keys.json')
keys = json.load(open(path))
keys = [k for k in keys if k != 'TEST_LEAK_KEY']
json.dump(keys, open(path, 'w'))
"

# ============================================================
header "5. SessionStart — session_start.py"
# ============================================================

OUTPUT=$(echo '{"session_id": "test", "hook_event_name": "SessionStart", "source": "startup"}' \
    | python3 "$HOOKS_DIR/session_start.py" 2>&1); EXIT=$?
assert_exit "session_start exits 0" "0" "$EXIT"
assert_contains "output is valid JSON" "$OUTPUT" "hookSpecificOutput"
assert_contains "includes credential instructions" "$OUTPUT" "find-generic-password"
assert_contains "includes never-standalone rule" "$OUTPUT" "NEVER"

# ============================================================
header "6. Pause mechanism"
# ============================================================

# Pause
touch "$VAULT_DIR/paused"

OUTPUT=$(echo '{"prompt": "sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJ"}' \
    | python3 "$HOOKS_DIR/block_secrets.py" 2>&1); EXIT=$?
assert_exit "block_secrets: passes when paused" "0" "$EXIT"

OUTPUT=$(echo '{"session_id":"t","hook_event_name":"SessionStart","source":"startup"}' \
    | python3 "$HOOKS_DIR/session_start.py" 2>&1); EXIT=$?
assert_exit "session_start: no output when paused" "0" "$EXIT"
assert_not_contains "session_start: silent when paused" "$OUTPUT" "hookSpecificOutput"

# Unpause
rm "$VAULT_DIR/paused"

OUTPUT=$(echo '{"prompt": "sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJ"}' \
    | python3 "$HOOKS_DIR/block_secrets.py" 2>&1); EXIT=$?
assert_exit "block_secrets: blocks after unpause" "2" "$EXIT"

# ============================================================
header "7. Vault CLI"
# ============================================================

OUTPUT=$(python3 "$HOOKS_DIR/vault.py" list 2>&1); EXIT=$?
assert_exit "vault list runs" "0" "$EXIT"

# ============================================================
header "8. Uninstall"
# ============================================================

bash "$(dirname "$0")/uninstall.sh" <<< $'n\nn' > /dev/null 2>&1

SETTINGS_CONTENT=$(cat "$CLAUDE_SETTINGS" 2>/dev/null || echo "{}")
assert_not_contains "hooks removed from settings" "$SETTINGS_CONTENT" "block_secrets"
assert_not_contains "hooks removed from settings" "$SETTINGS_CONTENT" "check_leaks"
assert_not_contains "hooks removed from settings" "$SETTINGS_CONTENT" "session_start"

# Re-install for normal use
bash "$(dirname "$0")/install.sh" > /dev/null 2>&1

# Restore backup if it existed
if [ -f "$CLAUDE_SETTINGS.test-backup" ]; then
    rm -f "$CLAUDE_SETTINGS.test-backup"
fi

# ============================================================
header "Results"
# ============================================================

TOTAL=$((PASS + FAIL))
echo ""
if [ "$FAIL" -eq 0 ]; then
    green "All $TOTAL tests passed ✓"
else
    red "$FAIL of $TOTAL tests failed"
    echo ""
    exit 1
fi
