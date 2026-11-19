# Releasing SuperDock

`scripts/release.sh <version>` builds a universal Release app, signs it (inside-out, so Sparkle loads), makes a DMG, and updates the Homebrew cask checksum. Notarization, the update feed and publishing are switched on by the one-time setup below. Until then the script produces an **ad-hoc-signed test DMG** that runs on this Mac but would be blocked by Gatekeeper elsewhere.

## One-time setup

1. **Developer ID** (Apple Developer Program). In Xcode → Settings → Accounts → Manage Certificates, add a *Developer ID Application* certificate. Check it's there:
   ```sh
   security find-identity -v -p codesigning     # → "Developer ID Application: Your Name (TEAMID)"
   ```
2. **Notarization credentials**, stored in your keychain (use an app-specific password from appleid.apple.com):
   ```sh
   xcrun notarytool store-credentials superdock --apple-id you@example.com --team-id TEAMID
   ```
3. **Sparkle update key.** This creates an EdDSA key pair. The private key stays in your login keychain; the public key is printed. **Back the private key up** (`generate_keys -x private-key.txt`): if you lose it, existing installs can't verify future updates.
   ```sh
   build/release/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
   ```
   (Run `scripts/release.sh` once first so the Sparkle tools are downloaded.) Put the public key in `project.yml` → `SPARKLE_PUBLIC_KEY`, or export it as an environment variable for each release.
4. **Homebrew tap** (when you're ready to publish): create a public repo named `homebrew-superdock`, then add `packaging/homebrew/superdock.rb` to it as `Casks/superdock.rb`. Users then install with:
   ```sh
   brew install --cask apurvamukherjee/superdock/superdock
   ```

## Each release

```sh
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE=superdock
export SPARKLE_PUBLIC_KEY="…"          # skip if it's already in project.yml
scripts/release.sh 0.2.0 --publish
```

That will:

1. build with `MARKETING_VERSION=0.2.0` and a build number from the commit count;
2. sign the Sparkle XPC services, helpers, framework, then the app, all with the hardened runtime and a timestamp;
3. notarize and staple the app, then build, sign, notarize and staple the DMG;
4. update `packaging/homebrew/superdock.rb` (version and sha256);
5. write `appcast.xml` with Sparkle's `generate_appcast`, signing the update with your EdDSA key;
6. create GitHub release `v0.2.0` with the DMG and `appcast.xml`. Installed copies check `releases/latest/download/appcast.xml`.

Afterwards, commit the updated cask, and copy it into the tap repo.

`--publish` refuses to run without a Developer ID and notary profile, because users can't open unsigned downloads without working around Gatekeeper.

## Checking a release on a clean Mac

Use a fresh macOS user account or VM:

1. Download the DMG from the GitHub release, drag SuperDock to Applications and open it. There should be no Gatekeeper warning.
2. Onboarding: welcome → placement → Accessibility (grant it) → starter widgets. The bar appears beside the Dock.
3. Turn on Settings → Placement → Replace the system Dock, then quit from the menu bar icon. The system Dock comes back.
4. Settings → General → Check Now shows "You're up to date".
5. Uninstall with `brew uninstall --cask superdock` (it quits SuperDock first, which restores the Dock).
