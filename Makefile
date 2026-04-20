APP_NAME = MouseMap
BUNDLE_ID = com.mousemap.app
SRC_DIR = .
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app

SOURCES = $(wildcard $(SRC_DIR)/App/*.swift) \
          $(wildcard $(SRC_DIR)/Models/*.swift) \
          $(wildcard $(SRC_DIR)/Services/*.swift) \
          $(wildcard $(SRC_DIR)/ViewModels/*.swift) \
          $(wildcard $(SRC_DIR)/Views/*.swift)

.PHONY: all clean run

all: $(APP_BUNDLE)

$(APP_BUNDLE): $(SOURCES)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	swiftc \
		-o $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) \
		-target arm64-apple-macosx14.0 \
		-sdk $(shell xcrun --show-sdk-path) \
		-framework SwiftUI \
		-framework ApplicationServices \
		-framework Cocoa \
		$(SOURCES)
	find $(APP_BUNDLE) -name "._*" -delete
	codesign --force --sign - --identifier $(BUNDLE_ID) $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR)

run: $(APP_BUNDLE)
	open $(APP_BUNDLE)
