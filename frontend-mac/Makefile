# Luma Makefile
# -----------------
# Helpful targets:
#   make build    - debug build for developers
#   make run      - run the debug build
#   make release  - optimized build (needed before bundling)
#   make bundle   - wraps the release binary in a .app bundle (../dist/Luma.app)
#   make dmg      - builds a signed DMG at ../dist/Luma.dmg for easy sharing
#   make clean    - removes Swift build artifacts and packaged output

APP_NAME := Luma
DIST_DIR := ../dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
DMG_ROOT := $(DIST_DIR)/dmg-root
DMG_FILE := $(DIST_DIR)/$(APP_NAME).dmg
VOLUME_NAME := Luma
LUMA_BACKEND_URL ?= http://localhost:8080

.PHONY: all build run release bundle dmg clean

all: build

build:
	swift build

run:
	LUMA_BACKEND_URL=$(LUMA_BACKEND_URL) swift run $(APP_NAME)

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
	'    <key>NSInputMonitoringUsageDescription</key>' \
	'    <string>Luma needs Input Monitoring to capture global shortcuts (e.g., Right Option) even when you are in other apps.</string>' \
	'    <key>NSApplicationSupportsAutomaticGraphicsSwitching</key>' \
	'    <true/>' \
	'    <key>LumaBackendURL</key>' \
	'    <string>$(LUMA_BACKEND_URL)</string>' \
	'</dict>' \
	'</plist>' \
	> $$APP_ROOT/Info.plist
	cp -R $(APP_BUNDLE) $(DMG_ROOT)/

dmg: bundle
	# Add Applications alias so the DMG shows a simple drag-to-install layout.
	@if [ ! -e $(DMG_ROOT)/Applications ]; then ln -s /Applications $(DMG_ROOT)/Applications; fi
	@rm -f $(DMG_FILE)
	hdiutil create -volname "$(VOLUME_NAME)" -srcfolder $(DMG_ROOT) -ov -format UDZO $(DMG_FILE)
	@MNT=$$(mktemp -d /tmp/luma-dmg-XXXX); \
	hdiutil attach -quiet -mountpoint $$MNT $(DMG_FILE); \
	sleep 1; \
	osascript \
		-e 'set dmgFolder to POSIX file "'$$MNT'"' \
		-e 'tell application "Finder"' \
		-e 'set w to open dmgFolder' \
		-e 'set w to window 1' \
		-e 'set target of w to dmgFolder' \
		-e 'set current view of w to icon view' \
		-e 'set toolbar visible of w to false' \
		-e 'set statusbar visible of w to false' \
		-e 'set bounds of w to {200, 200, 800, 500}' \
		-e 'set theViewOptions to icon view options of w' \
		-e 'set arrangement of theViewOptions to not arranged' \
		-e 'set icon size of theViewOptions to 128' \
		-e 'try' \
		-e 'set position of item "Luma.app" of w to {400, 220}' \
		-e 'set position of item "Applications" of w to {150, 220}' \
		-e 'end try' \
		-e 'delay 1' \
		-e 'close w' \
		-e 'end tell'; \
	hdiutil detach -quiet $$MNT

clean:
	swift package clean
	rm -rf .build $(DIST_DIR)
