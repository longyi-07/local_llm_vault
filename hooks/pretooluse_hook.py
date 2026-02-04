#!/usr/bin/env python3
"""
LLM Vault - PreToolUse Hook
Injects cached credentials into tool executions
This runs BEFORE any tool (Bash, Read, etc.) executes
"""

import json
import sys
import os

# Add lib to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'lib'))

from credential_manager import SessionCache


def inject_credentials_into_command(command: str, credentials: dict) -> str:
    """
    Inject credentials into a bash command as environment variables

    Args:
        command: The original bash command
        credentials: Dict of {KEY_NAME: value}

    Returns:
        Modified command with credentials as env vars
    """
    if not credentials:
        return command

    # Build env var prefix
    env_vars = []
    for key, value in credentials.items():
        # Escape single quotes in value
        escaped_value = value.replace("'", "'\\''")
        env_vars.append(f"{key}='{escaped_value}'")

    # Prepend env vars to command
    env_prefix = ' '.join(env_vars)
    return f"{env_prefix} {command}"


def main():
    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error parsing input: {e}", file=sys.stderr)
        sys.exit(0)

    tool_name = hook_input.get('tool_name')
    tool_input = hook_input.get('tool_input', {})
    session_id = hook_input.get('session_id', 'default')

    # Only inject into Bash commands for now
    # TODO: Support other tools if needed (Write, Edit with environment context)
    if tool_name != 'Bash':
        sys.exit(0)

    command = tool_input.get('command', '')

    if not command:
        sys.exit(0)

    # Load session cache
    cache = SessionCache(session_id)
    cached_credentials = cache.get_all()

    if not cached_credentials:
        # No credentials to inject
        sys.exit(0)

    # Inject credentials
    modified_command = inject_credentials_into_command(command, cached_credentials)

    if modified_command == command:
        # No changes made
        sys.exit(0)

    # Log injection to stderr
    print(f"\n🔐 LLM Vault: Injecting {len(cached_credentials)} credential(s)", file=sys.stderr)
    for key in cached_credentials.keys():
        print(f"   - {key}", file=sys.stderr)

    # Return modified tool input
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "updatedInput": {
                "command": modified_command
            },
            "additionalContext": f"Credentials injected: {', '.join(cached_credentials.keys())}"
        }
    }

    print(json.dumps(output, indent=2))
    sys.exit(0)


if __name__ == '__main__':
    main()
