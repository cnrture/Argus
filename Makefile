SCHEME = NotchPilot
PROJECT = NotchPilot/NotchPilot.xcodeproj
ARCHIVE_PATH = build/NotchPilot.xcarchive
EXPORT_PATH = build/export
DMG_PATH = build/NotchPilot.dmg

.PHONY: build archive export sign notarize dmg clean bridge

build:
	cd NotchPilot && xcodebuild -project NotchPilot.xcodeproj \
		-scheme $(SCHEME) -configuration Debug \
		-destination 'platform=macOS' build

bridge:
	cd NotchPilot && xcodebuild -project NotchPilot.xcodeproj \
		-scheme notchpilot-bridge -configuration Release \
		-destination 'platform=macOS' build

archive:
	cd NotchPilot && xcodebuild archive \
		-project NotchPilot.xcodeproj \
		-scheme $(SCHEME) \
		-archivePath ../$(ARCHIVE_PATH) \
		-configuration Release

export: archive
	cd NotchPilot && xcodebuild -exportArchive \
		-archivePath ../$(ARCHIVE_PATH) \
		-exportPath ../$(EXPORT_PATH) \
		-exportOptionsPlist ExportOptions.plist

sign:
	codesign --force --deep --sign "Developer ID Application" \
		$(EXPORT_PATH)/NotchPilot.app

notarize:
	ditto -c -k --keepParent $(EXPORT_PATH)/NotchPilot.app build/NotchPilot.zip
	xcrun notarytool submit build/NotchPilot.zip \
		--apple-id "$(APPLE_ID)" \
		--password "$(APPLE_APP_PASSWORD)" \
		--team-id "$(APPLE_TEAM_ID)" \
		--wait
	xcrun stapler staple $(EXPORT_PATH)/NotchPilot.app

dmg: export
	hdiutil create -volname "NotchPilot" \
		-srcfolder $(EXPORT_PATH)/NotchPilot.app \
		-ov -format UDZO $(DMG_PATH)
	@echo "DMG created at $(DMG_PATH)"

clean:
	rm -rf build/
	cd NotchPilot && xcodebuild clean \
		-project NotchPilot.xcodeproj -scheme $(SCHEME)
