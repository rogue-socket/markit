.PHONY: build install clean

APP_NAME = mdgrill
APP_BUNDLE = .build/$(APP_NAME).app

build:
	swift build -c release
	@BIN_PATH=$$(swift build -c release --show-bin-path) && \
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" && \
	cp "$$BIN_PATH/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)" && \
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist" && \
	codesign -s - --force "$(APP_BUNDLE)"
	@echo "Built $(APP_BUNDLE)"

install: build
	cp -R "$(APP_BUNDLE)" /Applications/$(APP_NAME).app
	@echo "Installed to /Applications/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
