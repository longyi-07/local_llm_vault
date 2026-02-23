---
name: llm-vault
description: Secure credential management — retrieve and use secrets from macOS Keychain without exposing them in conversation
---

# LLM Vault — Secure Credential Usage

You have access to credentials stored in macOS Keychain via the `vault` CLI at `~/.llm-vault/hooks/vault`.

## Retrieving credentials

**ALWAYS** use inline substitution so the value never appears in conversation:

```bash
API_KEY=$(~/.llm-vault/hooks/vault get KEY_NAME) \
  some-command --key "$API_KEY"
```

Multiple credentials in one command:

```bash
AWS_ACCESS_KEY_ID=$(~/.llm-vault/hooks/vault get AWS_ACCESS_KEY_ID) \
AWS_SECRET_ACCESS_KEY=$(~/.llm-vault/hooks/vault get AWS_SECRET_ACCESS_KEY) \
  aws s3 cp build/ s3://my-bucket/
```

## Rules — never break these

1. **NEVER** run `vault get` or `security find-generic-password -w` as a standalone command.
   The value would appear in tool output and leak into conversation history.

2. **NEVER** echo, print, log, or write a credential value to any file or output.
   Do not run `echo $SECRET`, `env`, or pipe a credential to stdout.

3. **NEVER** ask the user to paste, type, or share a credential in the chat.
   If you need a credential, guide the user to store it (see below).

4. **NEVER** hardcode a credential value in any file you write or edit.

## When a credential is missing

If a command fails because a credential is not set, guide the user:

```
The command needs AWS_ACCESS_KEY_ID but it's not in your vault yet.

Store it securely (value is hidden as you type):

    ~/.llm-vault/hooks/vault store AWS_ACCESS_KEY_ID

Then tell me to retry and I'll pick it up automatically.
```

## Checking what credentials are available

Names only, never values:

```bash
~/.llm-vault/hooks/vault list
~/.llm-vault/hooks/vault check KEY_NAME
```

## LLM Vault menu bar app

If the user prefers a GUI for managing credentials:

```bash
open -a LocalLLMVault
```
