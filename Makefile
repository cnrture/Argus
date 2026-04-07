SCHEME = Argus
PROJECT = Argus/Argus.xcodeproj
ARCHIVE_PATH = build/Argus.xcarchive
EXPORT_PATH = build/export
DMG_PATH = build/Argus.dmg

.PHONY: build archive export sign notarize dmg clean bridge

build:
	cd Argus && xcodebuild -project Argus.xcodeproj \
		-scheme $(SCHEME) -configuration Debug \
		-destination 'platform=macOS' build

bridge:
	cd Argus && xcodebuild -project Argus.xcodeproj \
		-scheme argus-bridge -configuration Release \
		-destination 'platform=macOS' build

archive:
	cd Argus && xcodebuild archive \
		-project Argus.xcodeproj \
		-scheme $(SCHEME) \
		-archivePath ../$(ARCHIVE_PATH) \
		-configuration Release

export: archive
	cd Argus && xcodebuild -exportArchive \
		-archivePath ../$(ARCHIVE_PATH) \
		-exportPath ../$(EXPORT_PATH) \
		-exportOptionsPlist ExportOptions.plist

sign:
	codesign --force --deep --sign "Developer ID Application" \
		$(EXPORT_PATH)/Argus.app

notarize:
	ditto -c -k --keepParent $(EXPORT_PATH)/Argus.app build/Argus.zip
	xcrun notarytool submit build/Argus.zip \
		--apple-id "$(APPLE_ID)" \
		--password "$(APPLE_APP_PASSWORD)" \
		--team-id "$(APPLE_TEAM_ID)" \
		--wait
	xcrun stapler staple $(EXPORT_PATH)/Argus.app

dmg: export
	hdiutil create -volname "Argus" \
		-srcfolder $(EXPORT_PATH)/Argus.app \
		-ov -format UDZO $(DMG_PATH)
	@echo "DMG created at $(DMG_PATH)"

clean:
	rm -rf build/
	cd Argus && xcodebuild clean \
		-project Argus.xcodeproj -scheme $(SCHEME)
