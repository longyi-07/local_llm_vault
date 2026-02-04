#!/bin/bash
# LLM Vault - Fully Automated Build Script
# Creates Xcode project and builds the app

set -e

echo "🔐 LLM Vault - Fully Automated Build"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode is not installed${NC}"
    echo "   Please install Xcode from the Mac App Store"
    exit 1
fi

echo -e "${GREEN}✓${NC} Xcode found"

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME="LLMVault"
PROJECT_FILE="$PROJECT_DIR/$APP_NAME.xcodeproj"

# Check if project already exists
if [ -d "$PROJECT_FILE" ]; then
    echo -e "${YELLOW}⚠️  Xcode project already exists${NC}"
    echo "   Location: $PROJECT_FILE"
    echo ""
    read -p "   Do you want to rebuild? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "   Skipping project creation..."
    else
        echo "   Removing old project..."
        rm -rf "$PROJECT_FILE"
    fi
fi

# If project doesn't exist, we need to create it with Xcode
if [ ! -d "$PROJECT_FILE" ]; then
    echo ""
    echo -e "${YELLOW}📝 Xcode project needs to be created${NC}"
    echo ""
    echo "I'll open Xcode for you. Please:"
    echo "1. File → New → Project"
    echo "2. Select: macOS → App"
    echo "3. Product Name: LLMVault"
    echo "4. Interface: SwiftUI"
    echo "5. Language: Swift"
    echo "6. Save to: $PROJECT_DIR"
    echo ""
    echo "Then:"
    echo "7. Delete default LLMVaultApp.swift and ContentView.swift"
    echo "8. Drag all .swift files from LLMVault/ folder into project"
    echo "9. In Info tab, add: LSUIElement = YES (Boolean)"
    echo "10. Press ⌘R to build and run"
    echo ""
    read -p "Press Enter to open Xcode..."

    open -a Xcode

    echo ""
    echo -e "${GREEN}✓${NC} Xcode opened"
    echo ""
    echo "After creating the project in Xcode, run this script again to build."
    echo ""
    exit 0
fi

# Build the project
echo ""
echo "🔨 Building $APP_NAME..."
echo ""

cd "$PROJECT_DIR"

# Build for release
xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath ./DerivedData \
    build

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}✅ Build successful!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""

    # Find the built app
    APP_PATH=$(find ./DerivedData -name "$APP_NAME.app" -type d | head -1)

    if [ -n "$APP_PATH" ]; then
        echo "📦 App built at:"
        echo "   $APP_PATH"
        echo ""

        # Copy to build directory
        mkdir -p "$PROJECT_DIR/build"
        cp -R "$APP_PATH" "$PROJECT_DIR/build/"

        echo -e "${GREEN}✓${NC} Copied to: $PROJECT_DIR/build/$APP_NAME.app"
        echo ""

        # Ask to run
        read -p "🚀 Launch the app now? (Y/n): " -n 1 -r
        echo ""

        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "Launching $APP_NAME..."
            open "$PROJECT_DIR/build/$APP_NAME.app"
            echo ""
            echo -e "${GREEN}✓${NC} App launched! Look for the 🔒 icon in your menu bar."
        fi
    else
        echo -e "${YELLOW}⚠️  Could not find built app${NC}"
        echo "   It should be in: ./DerivedData/Build/Products/Release/"
    fi
else
    echo ""
    echo -e "${RED}❌ Build failed!${NC}"
    echo ""
    echo "Common issues:"
    echo "1. Missing LSUIElement in Info.plist"
    echo "2. Missing Swift files in project"
    echo "3. Wrong deployment target (needs macOS 12.0+)"
    echo ""
    echo "Open project in Xcode to see errors:"
    echo "  open $PROJECT_FILE"
    exit 1
fi

echo ""
