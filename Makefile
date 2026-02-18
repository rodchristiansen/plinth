# Plinth Build Configuration
# Load from environment or .env file

BUNDLE_ID = ca.ecuad.macadmins.plinth
APP_NAME = Plinth
VERSION = 1.0.0
BUILD_NUMBER = 1

# Target architecture: empty = native, x86_64 = Intel, arm64 = Apple Silicon
ARCH ?=
ifneq ($(ARCH),)
SWIFT_ARCH_FLAG = --arch $(ARCH)
else
SWIFT_ARCH_FLAG =
endif

# Build directories
BUILD_DIR = .build
DIST_DIR = dist
RELEASE_DIR = $(BUILD_DIR)/release
APP_BUNDLE = $(DIST_DIR)/$(APP_NAME).app

# Signing (override in .env or environment)
SIGNING_IDENTITY ?= Developer ID Application: Emily Carr University of Art and Design (7TF6CSP83S)
INSTALLER_IDENTITY ?= Developer ID Installer: Emily Carr University of Art and Design (7TF6CSP83S)
KEYCHAIN ?= $(HOME)/Library/Keychains/signing.keychain
NOTARIZATION_PROFILE ?= notarization_credentials

# Timestamps
TIMESTAMP_SERVER = http://timestamp.apple.com/ts01

# Build tools
SWIFT = swift
CODESIGN = codesign
PRODUCTSIGN = productsign
NOTARYTOOL = xcrun notarytool
STAPLER = xcrun stapler
HDIUTIL = hdiutil
PKGBUILD = pkgbuild

.PHONY: all clean build app sign pkg dmg notarize release intel build-universal universal test help

help:
	@echo "Plinth Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all         - Full release pipeline: clean, test, build, sign, pkg, dmg, notarize (default)"
	@echo "  build       - Build Swift package (native arch)"
	@echo "  intel       - Full pipeline for Intel x86_64"
	@echo "  universal   - Full pipeline for universal binary (arm64 + x86_64)"
	@echo "  app         - Create app bundle"
	@echo "  sign        - Code sign app bundle"
	@echo "  pkg         - Create signed installer package"
	@echo "  dmg         - Create DMG distribution"
	@echo "  notarize    - Submit for notarization"
	@echo "  release     - Same as 'all'"
	@echo "  test        - Run unit tests"
	@echo "  clean       - Clean build artifacts"
	@echo ""
	@echo "Architecture:"
	@echo "  make build ARCH=x86_64   - Build for Intel"
	@echo "  make build ARCH=arm64    - Build for Apple Silicon"
	@echo "  make intel               - Full pipeline targeting Intel x86_64"
	@echo "  make universal           - Full pipeline with universal binary"
	@echo ""
	@echo "Environment variables:"
	@echo "  SIGNING_IDENTITY      - Developer ID Application certificate"
	@echo "  INSTALLER_IDENTITY    - Developer ID Installer certificate"
	@echo "  KEYCHAIN              - Path to signing keychain"
	@echo "  NOTARIZATION_PROFILE  - Keychain profile for notarization"

all: clean test build app sign pkg dmg notarize
	@echo ""
	@echo "Complete build finished!"
	@echo "  Package: $(APP_NAME).pkg"
	@echo "  DMG: $(APP_NAME).dmg"
	@echo "Both are signed and notarized."

intel:
	$(MAKE) ARCH=x86_64 clean test build app sign pkg dmg notarize

build-universal:
	@echo "Building $(APP_NAME) for arm64..."
	$(SWIFT) build -c release --arch arm64
	@echo "Building $(APP_NAME) for x86_64..."
	$(SWIFT) build -c release --arch x86_64
	@echo "Creating universal binary..."
	lipo -create -output $(BUILD_DIR)/release/$(APP_NAME) \
		$(BUILD_DIR)/arm64-apple-macosx/release/$(APP_NAME) \
		$(BUILD_DIR)/x86_64-apple-macosx/release/$(APP_NAME)
	@lipo -info $(BUILD_DIR)/release/$(APP_NAME)

universal: clean test build-universal app sign pkg dmg notarize
	@echo ""
	@echo "Universal build complete!"

clean:
	rm -rf $(DIST_DIR)
	rm -f $(APP_NAME).dmg $(APP_NAME).pkg
	$(SWIFT) package clean

build:
	@echo "Building $(APP_NAME)$(if $(ARCH), for $(ARCH),)..."
	$(SWIFT) build -c release $(SWIFT_ARCH_FLAG)

test:
	@echo "Running tests..."
	$(SWIFT) test

app:
	@echo "Creating app bundle..."
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@mkdir -p $(APP_BUNDLE)/Contents/Library/LaunchAgents
	
	# Copy binary
	cp $(RELEASE_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	
	# Copy Info.plist
	cp Sources/$(APP_NAME)/Resources/Info.plist $(APP_BUNDLE)/Contents/
	
	# Copy LaunchAgent
	cp Sources/$(APP_NAME)/Resources/LaunchAgents/*.plist $(APP_BUNDLE)/Contents/Library/LaunchAgents/
	
	# Copy Assets (if compiled)
	@if [ -d "$(RELEASE_DIR)/$(APP_NAME)_$(APP_NAME).bundle" ]; then \
		cp -R $(RELEASE_DIR)/$(APP_NAME)_$(APP_NAME).bundle $(APP_BUNDLE)/Contents/Resources/; \
	fi
	
	@echo "App bundle created at $(APP_BUNDLE)"

sign: app
	@echo "Signing app bundle..."
	@if [ -z "$(SIGNING_IDENTITY)" ]; then \
		echo "Error: SIGNING_IDENTITY not set"; \
		exit 1; \
	fi
	
	# Unlock keychain if specified
	@if [ -n "$(KEYCHAIN)" ] && [ -f "$(KEYCHAIN)" ]; then \
		security unlock-keychain $(KEYCHAIN); \
	fi
	
	# Sign LaunchAgent first
	$(CODESIGN) --force --sign "$(SIGNING_IDENTITY)" \
		--timestamp --options runtime \
		--entitlements Sources/$(APP_NAME)/Resources/Plinth.entitlements \
		$(APP_BUNDLE)/Contents/Library/LaunchAgents/*.plist
	
	# Sign main executable
	$(CODESIGN) --force --sign "$(SIGNING_IDENTITY)" \
		--timestamp --options runtime \
		--entitlements Sources/$(APP_NAME)/Resources/Plinth.entitlements \
		$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	
	# Sign app bundle
	$(CODESIGN) --force --sign "$(SIGNING_IDENTITY)" \
		--timestamp --options runtime \
		--entitlements Sources/$(APP_NAME)/Resources/Plinth.entitlements \
		$(APP_BUNDLE)
	
	@echo "Verifying signature..."
	@$(CODESIGN) -vvv --deep --strict $(APP_BUNDLE)
	@echo "App bundle signed successfully"

pkg: sign
	@echo "Creating installer package..."
	@if [ -z "$(INSTALLER_IDENTITY)" ]; then \
		echo "Error: INSTALLER_IDENTITY not set"; \
		exit 1; \
	fi
	
	# Create component package
	$(PKGBUILD) --root $(DIST_DIR) \
		--identifier $(BUNDLE_ID) \
		--version $(VERSION) \
		--install-location /Applications \
		--sign "$(INSTALLER_IDENTITY)" \
		--timestamp \
		$(APP_NAME)-unsigned.pkg
	
	# Sign the package
	$(PRODUCTSIGN) --sign "$(INSTALLER_IDENTITY)" \
		--timestamp \
		$(APP_NAME)-unsigned.pkg \
		$(APP_NAME).pkg
	
	@rm -f $(APP_NAME)-unsigned.pkg
	@echo "Installer package created: $(APP_NAME).pkg"

dmg: sign
	@echo "Creating DMG..."
	@rm -f $(APP_NAME).dmg
	$(HDIUTIL) create -volname "$(APP_NAME)" \
		-srcfolder $(DIST_DIR) \
		-ov -format UDZO \
		$(APP_NAME).dmg
	
	@echo "Signing DMG..."
	$(CODESIGN) --force --sign "$(SIGNING_IDENTITY)" \
		--timestamp \
		$(APP_NAME).dmg
	
	@echo "DMG created: $(APP_NAME).dmg"

notarize: pkg dmg
	@echo "Submitting for notarization..."
	@if [ -z "$(NOTARIZATION_PROFILE)" ]; then \
		echo "Error: NOTARIZATION_PROFILE not set"; \
		exit 1; \
	fi
	
	# Submit PKG
	@echo "Notarizing PKG..."
	$(NOTARYTOOL) submit $(APP_NAME).pkg \
		--keychain-profile "$(NOTARIZATION_PROFILE)" \
		--wait
	
	# Staple PKG
	$(STAPLER) staple $(APP_NAME).pkg
	
	# Submit DMG
	@echo "Notarizing DMG..."
	$(NOTARYTOOL) submit $(APP_NAME).dmg \
		--keychain-profile "$(NOTARIZATION_PROFILE)" \
		--wait
	
	# Staple DMG
	$(STAPLER) staple $(APP_NAME).dmg
	
	@echo "Notarization complete"

release: all

# Development helpers
run: build
	$(RELEASE_DIR)/$(APP_NAME)

dev:
	$(SWIFT) run

debug:
	$(SWIFT) build

.DEFAULT_GOAL := help
