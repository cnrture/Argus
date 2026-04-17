SCHEME = Argus
PROJECT = Argus/Argus.xcodeproj
ARCHIVE_PATH = build/Argus.xcarchive
EXPORT_PATH = build/export
DMG_PATH = build/Argus.dmg

.PHONY: build archive export sign notarize dmg clean bridge release

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
		-configuration Release \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="Developer ID Application" \
		DEVELOPMENT_TEAM=39Z244SGXG

export: archive
	rm -rf $(EXPORT_PATH)
	mkdir -p $(EXPORT_PATH)
	cp -R $(ARCHIVE_PATH)/Products/Applications/Argus.app $(EXPORT_PATH)/Argus.app

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

release:
	./scripts/release.sh

clean:
	rm -rf build/ release/
	cd Argus && xcodebuild clean \
		-project Argus.xcodeproj -scheme $(SCHEME)


