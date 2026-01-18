#!/bin/bash
# package_app.sh - Build and package ReviewBar.app
# Usage: ./Scripts/package_app.sh
# Set REVIEWBAR_SIGNING=adhoc for ad-hoc signing (no Apple Developer account)

set -e

APP_NAME="ReviewBar"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

echo "🔨 Building release..."
swift build -c release

echo "📦 Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.reviewbar.ReviewBar</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
EOF

# Copy icon if exists
if [ -f "Icon.icns" ]; then
    cp Icon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Sign the app
if [ "$REVIEWBAR_SIGNING" = "adhoc" ]; then
    echo "🔏 Ad-hoc signing..."
    codesign --force --deep --sign - "$APP_BUNDLE"
else
    echo "🔏 Signing with Developer ID (if available)..."
    codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || echo "⚠️  No signing identity found, using ad-hoc"
fi

echo "✅ Built: $APP_BUNDLE"
echo ""
echo "To run: open $APP_BUNDLE"
