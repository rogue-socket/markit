.PHONY: build dist install clean run

APP_NAME = markit
APP_BUNDLE = .build/$(APP_NAME).app
DIST_ZIP = .build/$(APP_NAME)-macos.zip
INSTALL_DIR = /Applications

build:
	swift build -c release
	@BIN_PATH=$$(swift build -c release --show-bin-path) && \
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" && \
	cp "$$BIN_PATH/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)" && \
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist" && \
	codesign -s - --force "$(APP_BUNDLE)"
	@echo "Built $(APP_BUNDLE)"

dist: build
	rm -f "$(DIST_ZIP)"
	ditto -c -k --keepParent "$(APP_BUNDLE)" "$(DIST_ZIP)"
	@echo "Built $(DIST_ZIP)"

install: build
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

run: build
	@pkill -x markit 2>/dev/null; sleep 0.3; true
	@open "$(APP_BUNDLE)" --args $(FILE)

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
