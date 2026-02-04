#!/usr/bin/env python3
"""
LLM Vault CLI - Command-line interface for managing credentials
"""

import sys
import os

# Add lib to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'lib'))

from credential_manager import CredentialManager
import argparse


def cmd_add(args):
    """Add a new credential"""
    manager = CredentialManager()

    # Get value from stdin or prompt
    if args.value:
        value = args.value
    else:
        import getpass
        value = getpass.getpass(f"Enter value for {args.name}: ")

    metadata = {
        'source': 'cli',
        'auto_inject': args.auto_inject
    }

    if args.context:
        metadata['context'] = args.context

    success = manager.store_credential(args.name, value, metadata)

    if success:
        print(f"✓ Stored {args.name} in keychain")
    else:
        print(f"✗ Failed to store {args.name}")
        sys.exit(1)


def cmd_get(args):
    """Get a credential value"""
    manager = CredentialManager()
    value = manager.get_credential(args.name)

    if value:
        if args.show:
            print(value)
        else:
            print(f"✓ {args.name} exists in keychain")
            print(f"  Value: {value[:5]}***{value[-5:]}")
    else:
        print(f"✗ {args.name} not found in keychain")
        sys.exit(1)


def cmd_list(args):
    """List all credentials"""
    manager = CredentialManager()
    creds = manager.list_credentials()

    if not creds:
        print("No credentials stored.")
        return

    print(f"Found {len(creds)} credential(s):\n")

    for cred in creds:
        print(f"  🔑 {cred['key_name']}")
        print(f"     Source: {cred.get('source', 'unknown')}")
        print(f"     Created: {cred.get('created_at', 'unknown')}")
        print(f"     Auto-inject: {cred.get('auto_inject', False)}")

        if cred.get('context'):
            context = cred['context']
            if len(context) > 60:
                context = context[:60] + '...'
            print(f"     Context: {context}")

        print()


def cmd_delete(args):
    """Delete a credential"""
    manager = CredentialManager()

    # Confirm deletion
    if not args.force:
        response = input(f"Delete {args.name}? (y/N): ")
        if not response.lower().startswith('y'):
            print("Cancelled.")
            return

    success = manager.delete_credential(args.name)

    if success:
        print(f"✓ Deleted {args.name}")
    else:
        print(f"✗ Failed to delete {args.name}")
        sys.exit(1)


def cmd_server(args):
    """Start the IPC server"""
    from ipc_server import VaultIPCServer

    print("🔐 Starting LLM Vault IPC server...")
    print("   Press Ctrl+C to stop")
    print()

    server = VaultIPCServer()

    try:
        server.start()
    except KeyboardInterrupt:
        print("\n✓ Server stopped")


def main():
    parser = argparse.ArgumentParser(
        description='LLM Vault - Secure credential management for AI coding assistants',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Add a credential
  vault-cli add AWS_ACCESS_KEY_ID --value AKIA... --auto-inject

  # Add a credential interactively (prompts for value)
  vault-cli add GITHUB_TOKEN

  # List all credentials
  vault-cli list

  # Get a credential
  vault-cli get AWS_ACCESS_KEY_ID

  # Delete a credential
  vault-cli delete AWS_ACCESS_KEY_ID

  # Start the IPC server
  vault-cli server
        """
    )

    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # Add command
    add_parser = subparsers.add_parser('add', help='Add a new credential')
    add_parser.add_argument('name', help='Credential name (e.g., AWS_ACCESS_KEY_ID)')
    add_parser.add_argument('--value', help='Credential value (if not provided, will prompt)')
    add_parser.add_argument('--context', help='Context or description')
    add_parser.add_argument('--auto-inject', action='store_true', default=True,
                           help='Auto-inject into commands (default: true)')
    add_parser.set_defaults(func=cmd_add)

    # Get command
    get_parser = subparsers.add_parser('get', help='Get a credential')
    get_parser.add_argument('name', help='Credential name')
    get_parser.add_argument('--show', action='store_true',
                           help='Show full value (otherwise redacted)')
    get_parser.set_defaults(func=cmd_get)

    # List command
    list_parser = subparsers.add_parser('list', help='List all credentials')
    list_parser.set_defaults(func=cmd_list)

    # Delete command
    delete_parser = subparsers.add_parser('delete', help='Delete a credential')
    delete_parser.add_argument('name', help='Credential name')
    delete_parser.add_argument('--force', '-f', action='store_true',
                              help='Skip confirmation')
    delete_parser.set_defaults(func=cmd_delete)

    # Server command
    server_parser = subparsers.add_parser('server', help='Start the IPC server')
    server_parser.set_defaults(func=cmd_server)

    # Parse arguments
    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    # Execute command
    args.func(args)


if __name__ == '__main__':
    main()
