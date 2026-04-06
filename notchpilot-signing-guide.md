# NotchPilot — Apple Code Signing & Notarization Rehberi

> macOS uygulamasını imzalama, notarize etme ve dağıtıma hazırlama adımları.

---

## Gereksinimler

- [x] Apple Developer Program hesabı ($99/yıl) — zaten var
- [ ] Xcode 16+ yüklü
- [ ] Apple Developer ID Application sertifikası
- [ ] App-specific password (notarization için)
- [ ] Developer Team ID

---

## Adım 1: Developer ID Sertifikası Oluşturma

Mac App Store **dışında** dağıtılan uygulamalar için "Developer ID Application" sertifikası gerekir.

### 1.1 Keychain Access ile CSR Oluştur

```
1. Keychain Access uygulamasını aç
2. Menüden: Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority
3. Doldur:
   - User Email Address: Apple ID e-postan
   - Common Name: Adın Soyadın
   - Request is: Saved to disk
4. "Continue" → CSR dosyasını kaydet
```

### 1.2 Apple Developer Portal'dan Sertifika Al

```
1. https://developer.apple.com/account/resources/certificates/list adresine git
2. "+" butonuna tıkla → "Developer ID Application" seç
3. Önceki adımda oluşturduğun CSR dosyasını yükle
4. "Download" ile .cer dosyasını indir
5. İndirilen .cer dosyasına çift tıkla → Keychain'e eklenir
```

### 1.3 Sertifikayı Doğrula

```bash
# Keychain'deki signing identity'leri listele
security find-identity -v -p codesigning

# Şuna benzer bir çıktı görmelisin:
# 1) ABCDEF1234567890 "Developer ID Application: Adın Soyadın (TEAM_ID)"
```

> **TEAM_ID'yi not et** — CI/CD ve notarization için lazım olacak.

---

## Adım 2: App-Specific Password Oluşturma

Notarization servisi Apple ID ile giriş yapar. 2FA aktifse (ki aktif olmalı) app-specific password gerekir.

```
1. https://appleid.apple.com/account/manage adresine git
2. "Sign-In and Security" → "App-Specific Passwords"
3. "Generate an app-specific password" tıkla
4. Label: "NotchPilot Notarization"
5. Şifreyi kopyala ve güvenli bir yere kaydet
```

---

## Adım 3: Xcode Proje Ayarları

### 3.1 Signing & Capabilities

```
1. NotchPilot.xcodeproj'u Xcode'da aç
2. Target: NotchPilot → Signing & Capabilities
3. Ayarla:
   - Team: Senin Developer hesabın
   - Signing Certificate: "Developer ID Application"
   - Bundle Identifier: com.cnrture.notchpilot
   - Hardened Runtime: ☑ Aktif (notarization için zorunlu)
```

### 3.2 Hardened Runtime Exceptions

Uygulama global keyboard shortcut yakalayacağı için:

```
Signing & Capabilities → + Capability → Hardened Runtime
  Exceptions:
    ☑ Accessibility (com.apple.security.accessibility)
```

### 3.3 Entitlements Dosyası

`NotchPilot/NotchPilot.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <!-- Sandbox kapalı: Unix socket, dosya sistemi erişimi, hook yazma için -->

    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <!-- Terminal uygulamalarına AppleScript göndermek için (gelecekte) -->
</dict>
</plist>
```

> **Not:** App Sandbox kapalı çünkü uygulama `~/.claude/settings.json` yazıyor, Unix socket oluşturuyor ve bridge binary çalıştırıyor. Mac App Store dağıtımı yapılmayacağı için sorun yok.

---

## Adım 4: Manuel Build & Sign (Yerel Test)

### 4.1 Archive Oluştur

```bash
xcodebuild archive \
  -project NotchPilot.xcodeproj \
  -scheme NotchPilot \
  -configuration Release \
  -archivePath build/NotchPilot.xcarchive \
  DEVELOPMENT_TEAM="TEAM_ID_BURAYA"
```

### 4.2 Export (Signed App)

```bash
xcodebuild -exportArchive \
  -archivePath build/NotchPilot.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

`ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>TEAM_ID_BURAYA</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

### 4.3 İmzayı Doğrula

```bash
# Code signature kontrolü
codesign --verify --deep --strict build/export/NotchPilot.app

# Detaylı bilgi
codesign -dv --verbose=4 build/export/NotchPilot.app

# Spctl ile Gatekeeper simülasyonu
spctl --assess --verbose=4 --type execute build/export/NotchPilot.app
```

---

## Adım 5: Notarization

Notarization, Apple'ın uygulamanı malware taramasından geçirmesidir. Geçerse "ticket" stapler edilir ve kullanıcılar uyarı görmeden açabilir.

### 5.1 Keychain'e Credentials Kaydet (Bir Kerelik)

```bash
xcrun notarytool store-credentials "NotchPilot" \
  --apple-id "senin@apple-id.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password-buraya"
```

### 5.2 ZIP Oluştur ve Gönder

```bash
# App'i zip'le (notarytool zip ister)
ditto -c -k --keepParent build/export/NotchPilot.app build/NotchPilot.zip

# Notarization'a gönder
xcrun notarytool submit build/NotchPilot.zip \
  --keychain-profile "NotchPilot" \
  --wait

# Başarılı olursa şöyle bir çıktı alırsın:
# status: Accepted
# id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### 5.3 Ticket'ı Staple Et

```bash
# Ticket'ı app'e yapıştır (offline doğrulama için)
xcrun stapler staple build/export/NotchPilot.app

# Doğrula
xcrun stapler validate build/export/NotchPilot.app
```

### 5.4 Notarization Hata Ayıklama

```bash
# Detaylı log al (submission ID ile)
xcrun notarytool log SUBMISSION_ID --keychain-profile "NotchPilot"
```

Yaygın hatalar:
| Hata | Çözüm |
|------|-------|
| "The signature is invalid" | Hardened Runtime aktif mi kontrol et |
| "The binary is not signed" | Bridge binary'yi de imzala: `codesign --sign "Developer ID" notchpilot-bridge` |
| "The executable has entitlements..." | Entitlements dosyasını kontrol et |

---

## Adım 6: DMG Oluşturma

### 6.1 create-dmg ile (Önerilen)

```bash
# create-dmg kur
brew install create-dmg

# DMG oluştur
create-dmg \
  --volname "NotchPilot" \
  --volicon "NotchPilot/Resources/Assets.xcassets/AppIcon.appiconset/icon_512.icns" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 100 \
  --icon "NotchPilot.app" 180 170 \
  --hide-extension "NotchPilot.app" \
  --app-drop-link 480 170 \
  --background "installer-background.png" \
  "build/NotchPilot-v1.0.0.dmg" \
  "build/export/"
```

### 6.2 DMG'yi de Notarize Et

```bash
xcrun notarytool submit build/NotchPilot-v1.0.0.dmg \
  --keychain-profile "NotchPilot" \
  --wait

xcrun stapler staple build/NotchPilot-v1.0.0.dmg
```

---

## Adım 7: GitHub Actions için CI/CD Kurulumu

### 7.1 GitHub Secrets Ekle

Repository → Settings → Secrets and variables → Actions → New repository secret:

| Secret Adı | Değer | Nasıl Alınır |
|-------------|-------|--------------|
| `APPLE_CERTIFICATE_P12_BASE64` | Sertifika (base64) | Aşağıdaki komutla |
| `APPLE_CERTIFICATE_PASSWORD` | P12 export şifresi | Kendin belirle |
| `APPLE_ID` | Apple ID e-posta | developer.apple.com |
| `APPLE_APP_PASSWORD` | App-specific password | Adım 2'deki |
| `APPLE_TEAM_ID` | Team ID | developer.apple.com → Membership |
| `KEYCHAIN_PASSWORD` | Geçici keychain şifresi | Rastgele bir şifre belirle |

### 7.2 P12 Sertifikasını Base64'e Çevir

```bash
# Keychain'den P12 olarak export et
# Keychain Access → Sertifikaya sağ tıkla → Export → .p12 formatı seç → Şifre belirle

# Base64'e çevir
base64 -i Certificates.p12 | pbcopy
# Panodaki değeri APPLE_CERTIFICATE_P12_BASE64 secret'ına yapıştır
```

### 7.3 Release Workflow

```yaml
# .github/workflows/release.yml
name: Build & Release

on:
  push:
    tags: ['v*']

jobs:
  build-and-release:
    runs-on: macos-15
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app

      - name: Install certificate
        env:
          P12_BASE64: ${{ secrets.APPLE_CERTIFICATE_P12_BASE64 }}
          P12_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
          KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
        run: |
          # Geçici keychain oluştur
          KEYCHAIN_PATH=$RUNNER_TEMP/signing.keychain-db
          security create-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
          security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH

          # P12'yi import et
          echo "$P12_BASE64" | base64 --decode > $RUNNER_TEMP/certificate.p12
          security import $RUNNER_TEMP/certificate.p12 \
            -P "$P12_PASSWORD" \
            -A -t cert -f pkcs12 \
            -k $KEYCHAIN_PATH
          security set-key-partition-list -S apple-tool:,apple: \
            -k "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
          security list-keychains -d user -s $KEYCHAIN_PATH

      - name: Build archive
        run: |
          xcodebuild archive \
            -project NotchPilot.xcodeproj \
            -scheme NotchPilot \
            -configuration Release \
            -archivePath build/NotchPilot.xcarchive \
            DEVELOPMENT_TEAM="${{ secrets.APPLE_TEAM_ID }}"

      - name: Export signed app
        run: |
          xcodebuild -exportArchive \
            -archivePath build/NotchPilot.xcarchive \
            -exportPath build/export \
            -exportOptionsPlist ExportOptions.plist

      - name: Notarize
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_APP_PASSWORD: ${{ secrets.APPLE_APP_PASSWORD }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          # ZIP oluştur
          ditto -c -k --keepParent build/export/NotchPilot.app build/NotchPilot.zip

          # Notarize
          xcrun notarytool submit build/NotchPilot.zip \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_APP_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" \
            --wait

          # Staple
          xcrun stapler staple build/export/NotchPilot.app

      - name: Create DMG
        run: |
          brew install create-dmg
          create-dmg \
            --volname "NotchPilot" \
            --window-pos 200 120 \
            --window-size 660 400 \
            --icon-size 100 \
            --icon "NotchPilot.app" 180 170 \
            --hide-extension "NotchPilot.app" \
            --app-drop-link 480 170 \
            "build/NotchPilot-${GITHUB_REF_NAME}.dmg" \
            "build/export/"

          # DMG'yi de notarize et
          xcrun notarytool submit "build/NotchPilot-${GITHUB_REF_NAME}.dmg" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_APP_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" \
            --wait
          xcrun stapler staple "build/NotchPilot-${GITHUB_REF_NAME}.dmg"

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: build/NotchPilot-*.dmg
          generate_release_notes: true

      - name: Cleanup keychain
        if: always()
        run: security delete-keychain $RUNNER_TEMP/signing.keychain-db
```

---

## Adım 8: Homebrew Cask Formülü

### 8.1 Kendi Tap'ini Oluştur

```bash
# GitHub'da yeni repo oluştur: cnrture/homebrew-tap
# İçine cask formülü ekle:
```

`Casks/notchpilot.rb`:
```ruby
cask "notchpilot" do
  version "1.0.0"
  sha256 "DMG_SHA256_HASH_BURAYA"

  url "https://github.com/cnrture/NotchPilot/releases/download/v#{version}/NotchPilot-v#{version}.dmg"
  name "NotchPilot"
  desc "Dynamic Island for AI coding agents on macOS"
  homepage "https://github.com/cnrture/NotchPilot"

  depends_on macos: ">= :sequoia"

  app "NotchPilot.app"

  uninstall quit: "com.cnrture.notchpilot"

  zap trash: [
    "~/Library/Preferences/com.cnrture.notchpilot.plist",
    "~/.notchpilot",
  ]
end
```

### 8.2 Kullanıcı Kurulumu

```bash
brew tap cnrture/tap
brew install --cask notchpilot
```

---

## Checklist

### Bir Kerelik Kurulum (Şimdi Yap)
- [ ] Developer ID Application sertifikası oluştur (Adım 1)
- [ ] App-specific password oluştur (Adım 2)
- [ ] Team ID'yi not et
- [ ] P12'yi base64'e çevir
- [ ] GitHub Secrets'ları ekle (Adım 7.1)

### Her Release Öncesi
- [ ] Version numarasını güncelle (Xcode + Cask)
- [ ] Tag oluştur ve pushla: `git tag v1.0.0 && git push origin v1.0.0`
- [ ] GitHub Actions'ın başarılı tamamlandığını kontrol et
- [ ] Release notes yaz
- [ ] Homebrew Cask SHA256'yı güncelle

### Doğrulama
- [ ] DMG'yi farklı bir Mac'te (veya farklı kullanıcıda) aç
- [ ] Gatekeeper uyarısı olmadan açıldığını doğrula
- [ ] `spctl --assess --verbose=4 --type execute /Applications/NotchPilot.app` → "accepted"
