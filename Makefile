.PHONY: build build-release generate-appicons

# App icon pipeline:
#   1. Composite assets/app-icon-large-transparent.png over assets/app-icon-background-large.png → assets/app-icon-large.png
#   2. Copy assets/app-icon-large.png → AppIcon_1024.png (source for all AppIcon sizes)
#   3. Resize AppIcon_1024 to 16, 32, 64, 128, 256, 512; also emit transparent 128x128 from large-transparent.
APPICON_DIR := SnipStash/Assets.xcassets/AppIcon.appiconset
APPICON_SRC := $(APPICON_DIR)/AppIcon_1024.png
APPICON_SIZES := 16 32 64 128 256 512
APPICON_BG := assets/app-icon-background-large.png
APPICON_LARGE := assets/app-icon-large.png

# Transparent icon: source of truth is assets/app-icon-large-transparent.png → 128x128 to both:
APPICON_TRANSPARENT_SRC := assets/app-icon-large-transparent.png
APPICON_TRANSPARENT_128 := assets/app-icon-transparent.png
APPICON_TRANSPARENT_IMAGESET := SnipStash/Assets.xcassets/AppIconTransparent.imageset/app-icon-transparent.png

# Override version at build time (e.g. TAGVER=1.0.0-demo make build-release).
# Writes SnipStash/Version.xcconfig so the app shows this version in About and Info.plist.
TAGVER ?=

build:
	mkdir -p build
	@if [ -n "$(TAGVER)" ]; then \
		printf 'MARKETING_VERSION = %s\nINFOPLIST_KEY_NSHumanReadableCopyright = Copyright © 2026 Centennial OSS\n' "$(TAGVER)" > SnipStash/Version.xcconfig; \
	fi
	xcodebuild -scheme SnipStash -configuration Debug -derivedDataPath build/DerivedData build
	cp -R build/DerivedData/Build/Products/Debug/SnipStash.app build/

build-release:
	mkdir -p dist
	@if [ -n "$(TAGVER)" ]; then \
		printf 'MARKETING_VERSION = %s\nINFOPLIST_KEY_NSHumanReadableCopyright = Copyright © 2026 Centennial OSS\n' "$(TAGVER)" > SnipStash/Version.xcconfig; \
	fi
	xcodebuild -scheme SnipStash -configuration Release -derivedDataPath dist/DerivedData build
	cp -R dist/DerivedData/Build/Products/Release/SnipStash.app dist/

# Generate app icon: composite transparent onto background → app-icon-large.png; copy to AppIcon_1024; then resize.
# Composite uses Swift script (no extra deps on macOS). 16 and 32: center-crop then resize; 64,128,256,512: resize only.
generate-appicons:
	@test -f $(APPICON_BG) || (echo "Missing: $(APPICON_BG)" && exit 1)
	@test -f $(APPICON_TRANSPARENT_SRC) || (echo "Missing: $(APPICON_TRANSPARENT_SRC)" && exit 1)
	@echo "Compositing app-icon-large-transparent.png onto app-icon-background-large.png → app-icon-large.png"
	@swift scripts/composite-app-icon.swift $(APPICON_BG) $(APPICON_TRANSPARENT_SRC) $(APPICON_LARGE)
	@cp $(APPICON_LARGE) $(APPICON_SRC)
	@echo "AppIcon_1024.png updated from app-icon-large.png"
	@test -f $(APPICON_SRC) || (echo "Missing source: $(APPICON_SRC)" && exit 1)
	@for size in $(APPICON_SIZES); do \
		echo "Creating AppIcon_$$size.png from AppIcon_1024.png"; \
		if [ "$$size" = "16" ]; then \
			sips --cropToHeightWidth 780 780 $(APPICON_SRC) --out /tmp/AppIcon_crop.png && \
			sips -z 16 16 /tmp/AppIcon_crop.png --out $(APPICON_DIR)/AppIcon_16.png; \
		elif [ "$$size" = "32" ]; then \
			sips --cropToHeightWidth 880 880 $(APPICON_SRC) --out /tmp/AppIcon_crop.png && \
			sips -z 32 32 /tmp/AppIcon_crop.png --out $(APPICON_DIR)/AppIcon_32.png; \
		else \
			sips -z $$size $$size --out $(APPICON_DIR)/AppIcon_$$size.png $(APPICON_SRC); \
		fi; \
	done
	@rm -f /tmp/AppIcon_crop.png
	@test -f $(APPICON_TRANSPARENT_SRC) || (echo "Missing source: $(APPICON_TRANSPARENT_SRC)" && exit 1)
	@echo "Creating app-icon-transparent.png (128x128) from app-icon-large-transparent.png"
	@sips -z 128 128 $(APPICON_TRANSPARENT_SRC) --out /tmp/app-icon-transparent-128.png
	@cp /tmp/app-icon-transparent-128.png $(APPICON_TRANSPARENT_128)
	@cp /tmp/app-icon-transparent-128.png $(APPICON_TRANSPARENT_IMAGESET)
	@rm -f /tmp/app-icon-transparent-128.png
	@echo "Done writing AppIcons and transparent 128x128"
