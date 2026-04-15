# Release scripts

Everything needed to build, sign, notarize and ship Argus.

## First-time setup (once per machine)

### 1. Install Sparkle tools

```bash
./scripts/setup-sparkle-tools.sh
```

Installs `generate_keys` and `sign_update` to `~/.sparkle-tools/bin`.

### 2. Generate the Argus ed25519 keypair

> Argus needs its own keypair, separate from any other app.

```bash
~/.sparkle-tools/bin/generate_keys
```

This prints the **public** key and stores the **private** key in your login keychain.
Copy the public key into `Argus/Argus/Info.plist`:

```xml
<key>SUPublicEDKey</key>
<string>PASTE_PUBLIC_KEY_HERE</string>
```

### 3. Back up the private key

```bash
./scripts/backup-sparkle-key.sh
```

Move the resulting file to secure storage (1Password, encrypted USB). **Losing this
key means every existing Argus install can no longer auto-update.**

### 4. Set up notarization credentials

Create an [app-specific password](https://appleid.apple.com) for your Apple ID, then:

```bash
xcrun notarytool store-credentials ArgusNotary \
    --apple-id YOUR_APPLE_ID \
    --team-id 39Z244SGXG \
    --password APP_SPECIFIC_PASSWORD
```

## Cutting a release

1. Bump `MARKETING_VERSION` in the Xcode project (Argus target → Build Settings).
2. Optionally create `RELEASE_NOTES_<version>.md` at the repo root for the changelog.
3. Run:

   ```bash
   make release
   # or: ./scripts/release.sh
   ```

The script:

- Archives via `xcodebuild` with Developer ID signing
- Exports the `.app`
- Notarizes and staples both the `.app` and the `.dmg`
- Produces `release/Argus.zip` (Sparkle) and `release/Argus.dmg` (Homebrew cask + direct download)
- Signs the ZIP with the Sparkle ed25519 key
- Prepends a new `<item>` entry to `appcast.xml` (deploy this file to the VPS so `https://argus.candroid.dev/appcast.xml` returns the new version)

It finishes by printing the DMG sha256 and copy-pasteable commands for pushing the
appcast, creating the GitHub release, and updating `Casks/argus.rb`.

## Hosting: Argus-Website (Docker blue-green on Hostinger VPS)

The `SUFeedURL` in `Info.plist` points to `https://argus.candroid.dev/appcast.xml`.
This URL is served by the **Argus-Website** repo (separate project) via a Dockerized
Vite build behind system nginx on the Hostinger VPS.

The `appcast.xml` in **this** repo is the source of truth. After `release.sh`
updates it, copy it into `Argus-Website/public/` and run that repo's
`deploy-docker.sh` (blue-green, zero-downtime).

**Architecture:**

```
argus.candroid.dev (DNS A → 145.223.98.186)
         │
   System nginx (VPS)  ─ proxies to ─▶  Docker container (blue 8286 OR green 8287)
                                               │
                                               └── serves / (Vite dist) + /appcast.xml
```

**Full release + deploy flow:**

```sh
# 1. In Argus (this) repo:
make release
git add appcast.xml && git commit -m "release: appcast entry for vX.Y.Z" && git push

# 2. Sync appcast to the website and deploy:
cp appcast.xml ../Argus-Website/public/appcast.xml
cd ../Argus-Website
./deploy-docker.sh

# 3. Verify:
curl -sI https://argus.candroid.dev/appcast.xml | head -1
```

**VPS one-time setup** (only if argus.candroid.dev isn't serving yet):

```sh
# On the VPS:
sudo cp /path/to/Argus-Website/nginx-system.conf \
    /etc/nginx/sites-available/argus.candroid.dev
sudo ln -s /etc/nginx/sites-available/argus.candroid.dev \
    /etc/nginx/sites-enabled/argus.candroid.dev
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d argus.candroid.dev
```

Ports: ClaudeSwitcher uses 8284/8285, Rune uses 8282/8283, Argus uses **8286/8287**.

## Files

| Script | Purpose |
|---|---|
| `setup-sparkle-tools.sh` | Install Sparkle `generate_keys` / `sign_update` |
| `backup-sparkle-key.sh` | Export Sparkle private key from keychain |
| `release.sh` | Full release pipeline (archive → notarize → ZIP + DMG → appcast) |
| `update-appcast.sh` | Idempotently add an `<item>` entry to `appcast.xml` |
