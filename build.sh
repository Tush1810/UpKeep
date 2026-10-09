#!/bin/zsh
set -eu
cd "${0:A:h}"
APP="$PWD/Upkeep.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build
for upkeep_arch in arm64 x86_64; do
    xcrun swiftc -target "$upkeep_arch-apple-macosx13.0" -swift-version 5 -O Source/main.swift -o ".build/Upkeep-$upkeep_arch" -framework AppKit -framework Carbon
done
xcrun lipo -create .build/Upkeep-arm64 .build/Upkeep-x86_64 -output "$APP/Contents/MacOS/Upkeep"
upkeep_archs=$(xcrun lipo -archs "$APP/Contents/MacOS/Upkeep")
for upkeep_arch in arm64 x86_64; do
    case " $upkeep_archs " in
        *" $upkeep_arch "*) ;;
        *) echo "Universal build is missing $upkeep_arch (found: $upkeep_archs)" >&2; exit 1 ;;
    esac
done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Upkeep</string>
<key>CFBundleDisplayName</key><string>Upkeep</string>
<key>CFBundleIdentifier</key><string>local.brew.menubar</string>
<key>CFBundleExecutable</key><string>Upkeep</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>CFBundleIconFile</key><string>Upkeep</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
mkdir -p .build/Upkeep.iconset
"$APP/Contents/MacOS/Upkeep" --export-icon .build/Upkeep-icon.png
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" .build/Upkeep-icon.png --out ".build/Upkeep.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" .build/Upkeep-icon.png --out ".build/Upkeep.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns .build/Upkeep.iconset -o "$APP/Contents/Resources/Upkeep.icns"
# Sign outside File Provider directories, where FinderInfo may be regenerated.
stage=$(mktemp -d /private/tmp/upkeep-sign.XXXXXX)
trap 'rm -rf "$stage"' EXIT
ditto --norsrc --noextattr --noqtn "$APP" "$stage/Upkeep.app"
xattr -cr "$stage/Upkeep.app"
codesign --force --sign - "$stage/Upkeep.app"
codesign --verify --deep --strict "$stage/Upkeep.app"
ditto --norsrc --noextattr --noqtn "$stage/Upkeep.app" "$APP"
ditto --norsrc --noextattr --noqtn -c -k --keepParent "$stage/Upkeep.app" "$PWD/Upkeep.zip"
echo "Built $APP"
