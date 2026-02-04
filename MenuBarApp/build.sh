#!/bin/bash
# LLM Vault - Automated Build Script
# Builds the menu bar app without manual Xcode setup

set -e

echo "🔐 LLM Vault - Automated Build"
echo "================================"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed"
    echo "   Please install Xcode from the Mac App Store"
    exit 1
fi

# Check Xcode license
if ! xcodebuild -checkFirstLaunchStatus &> /dev/null; then
    echo "⚠️  Xcode license needs to be accepted"
    echo "   Run: sudo xcodebuild -license accept"
    exit 1
fi

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="LLMVault"

echo "📁 Project directory: $PROJECT_DIR"
echo ""

# Create Package.swift for Swift Package Manager
echo "📝 Creating Swift Package..."

cat > "$PROJECT_DIR/Package.swift" << 'EOF'
// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "LLMVault",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "LLMVault",
            targets: ["LLMVault"]
        )
    ],
    targets: [
        .executableTarget(
            name: "LLMVault",
            path: "LLMVault"
        )
    ]
)
EOF

echo "✓ Package.swift created"
echo ""

# Create Info.plist
echo "📝 Creating Info.plist..."

mkdir -p "$PROJECT_DIR/Resources"

cat > "$PROJECT_DIR/Resources/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>LLMVault</string>
    <key>CFBundleIdentifier</key>
    <string>com.llmvault.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>LLM Vault</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 LLM Vault. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "✓ Info.plist created"
echo ""

# Build with Swift Package Manager
echo "🔨 Building application..."
echo ""

cd "$PROJECT_DIR"

# Clean previous builds
rm -rf "$BUILD_DIR"
rm -rf .build

# Build release version
swift build -c release --arch arm64 --arch x86_64

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Build failed!"
    echo ""
    echo "This is likely because Swift Package Manager can't build full macOS apps."
    echo "Let's try creating an Xcode project instead..."
    echo ""
    exit 1
fi

echo ""
echo "✓ Build completed"
echo ""

# Create app bundle
echo "📦 Creating app bundle..."

APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp .build/release/$APP_NAME "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp Resources/Info.plist "$APP_BUNDLE/Contents/"

# Make executable
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "✓ App bundle created at: $APP_BUNDLE"
echo ""

echo "================================"
echo "✅ Build successful!"
echo ""
echo "To run the app:"
echo "  open $APP_BUNDLE"
echo ""
echo "Or run this script with --run flag:"
echo "  ./build.sh --run"
echo ""
