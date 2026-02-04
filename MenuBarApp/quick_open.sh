#!/bin/bash
# Quick script to open everything you need

echo "🔐 LLM Vault - Opening Everything"
echo "=================================="
echo ""

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Open Xcode
echo "📱 Opening Xcode..."
open -a Xcode

sleep 2

# Open source files location in Finder
echo "📁 Opening source files in Finder..."
open "$PROJECT_DIR/LLMVault"

sleep 1

# Open Quick Start guide
echo "📚 Opening Quick Start guide..."
open "$PROJECT_DIR/QUICK_START.md"

echo ""
echo "✅ Everything opened!"
echo ""
echo "Next steps:"
echo "1. In Xcode: File → New → Project"
echo "2. Select: macOS → App"
echo "3. Name: LLMVault"
echo "4. Interface: SwiftUI, Language: Swift"
echo "5. Save to: $PROJECT_DIR"
echo "6. Delete default files"
echo "7. Drag .swift files from Finder into Xcode"
echo "8. Add Info.plist entry: LSUIElement = YES"
echo "9. Press ⌘R to run!"
echo ""
