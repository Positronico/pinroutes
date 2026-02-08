APP_NAME = PinRoutes
HELPER_NAME = pinroutes-helper
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
BINARY = $(BUILD_DIR)/$(APP_NAME)
HELPER_BINARY = $(BUILD_DIR)/$(HELPER_NAME)

.PHONY: build release bundle clean run

build:
	swift build

release:
	swift build -c release

bundle: release
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BINARY) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp $(HELPER_BINARY) $(APP_BUNDLE)/Contents/MacOS/$(HELPER_NAME)
	/usr/bin/printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'	<key>CFBundleExecutable</key>' \
		'	<string>$(APP_NAME)</string>' \
		'	<key>CFBundleIdentifier</key>' \
		'	<string>com.pinroutes.app</string>' \
		'	<key>CFBundleName</key>' \
		'	<string>$(APP_NAME)</string>' \
		'	<key>CFBundleVersion</key>' \
		'	<string>1.0</string>' \
		'	<key>CFBundleShortVersionString</key>' \
		'	<string>1.0</string>' \
		'	<key>CFBundlePackageType</key>' \
		'	<string>APPL</string>' \
		'	<key>LSMinimumSystemVersion</key>' \
		'	<string>13.0</string>' \
		'	<key>LSUIElement</key>' \
		'	<true/>' \
		'</dict>' \
		'</plist>' > $(APP_BUNDLE)/Contents/Info.plist

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)

run: bundle
	open $(APP_BUNDLE)
