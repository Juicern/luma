# LumaMac Makefile
# -----------------
# Helpful targets:
#   make build    - debug build for developers
#   make run      - run the debug build
#   make release  - optimized build (needed before bundling)
#   make bundle   - wraps the release binary in a .app bundle (../dist/LumaMac.app)
#   make dmg      - builds a signed DMG at ../dist/LumaMac.dmg for easy sharing
#   make clean    - removes Swift build artifacts and packaged output

APP_NAME := LumaMac
DIST_DIR := ../dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
DMG_ROOT := $(DIST_DIR)/dmg-root
DMG_FILE := $(DIST_DIR)/$(APP_NAME).dmg
VOLUME_NAME := Luma

.PHONY: all build run release bundle dmg clean

all: build

build:
	swift build

run:
	swift run $(APP_NAME)

release:
	swift build -c release

bundle: release
	@BIN_PATH=$$(swift build -c release --show-bin-path)/$(APP_NAME); \
	APP_ROOT=$(APP_BUNDLE)/Contents; \
	rm -rf $(APP_BUNDLE) $(DMG_ROOT); \
	mkdir -p $$APP_ROOT/MacOS $$APP_ROOT/Resources $(DMG_ROOT); \
	cp $$BIN_PATH $$APP_ROOT/MacOS/$(APP_NAME); \
	cp ../image.png $$APP_ROOT/Resources/AppIcon.png; \
	chmod +x $$APP_ROOT/MacOS/$(APP_NAME); \
	printf '%s\n' \
	'<?xml version="1.0" encoding="UTF-8"?>' \
	'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	'<plist version="1.0">' \
	'<dict>' \
	'    <key>CFBundleExecutable</key>' \
	'    <string>$(APP_NAME)</string>' \
	'    <key>CFBundleIconFile</key>' \
	'    <string>AppIcon.png</string>' \
	'    <key>CFBundleIdentifier</key>' \
	'    <string>com.juicern.luma</string>' \
	'    <key>CFBundleName</key>' \
	'    <string>Luma</string>' \
	'    <key>CFBundlePackageType</key>' \
	'    <string>APPL</string>' \
	'    <key>CFBundleShortVersionString</key>' \
	'    <string>0.1.0</string>' \
	'    <key>CFBundleVersion</key>' \
	'    <string>1</string>' \
	'    <key>LSMinimumSystemVersion</key>' \
	'    <string>13.0</string>' \
	'    <key>NSHighResolutionCapable</key>' \
	'    <true/>' \
	'    <key>NSMicrophoneUsageDescription</key>' \
	'    <string>Luma needs microphone access to capture prompts and content.</string>' \
	'    <key>NSApplicationSupportsAutomaticGraphicsSwitching</key>' \
	'    <true/>' \
	'    <key>LumaBackendURL</key>' \
	'    <string>http://35.175.191.70:8080</string>' \
	'</dict>' \
	'</plist>' \
	> $$APP_ROOT/Info.plist
	cp -R $(APP_BUNDLE) $(DMG_ROOT)/

dmg: bundle
	hdiutil create -volname "$(VOLUME_NAME)" -srcfolder $(DMG_ROOT) -ov -format UDZO $(DMG_FILE)

clean:
	swift package clean
	rm -rf .build $(DIST_DIR)
