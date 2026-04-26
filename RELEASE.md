# Release process — Masjid Timings

## Release keystore

A release keystore is at `android/app/upload-keystore.jks`. It is **NOT**
in git (see `.gitignore`). The signing password is in
`android/.RELEASE_KEYSTORE_PASSWORD_DONOTCOMMIT.txt` and referenced in
`android/key.properties`.

**LOSE THIS FILE = LOSE YOUR APP.** Back it up to:
- A password manager (1Password, Bitwarden) as an encrypted attachment
- An offline USB drive in a safe place
- A second device

If the keystore is lost, you cannot publish updates to the same Play Store
listing — Google will require you to publish as a brand-new app and all
users have to re-install from scratch.

## Get the release SHA-1 (for Google OAuth)

```bash
keytool -list -v -keystore android/app/upload-keystore.jks \
  -alias upload -storepass <STOREPASS>
```

Copy the SHA1 line. Add it as a **second SHA-1** to your existing Android
OAuth client at https://console.cloud.google.com/apis/credentials so
Google Sign-In works for both debug and release builds.

## Build a signed APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

The APK is now signed with the release keystore (because `key.properties`
exists and `app/build.gradle` reads from it).

**Resolved (2026-04-26):** AGP upgraded to 8.3.0, Gradle to 8.4, Java
compileOptions to 17, and core library desugaring enabled in
`android/app/build.gradle`. `flutter build apk --release` now produces a
properly release-signed ~26 MB APK.

## Build a Play Store AAB (App Bundle)

Google Play Store requires AAB, not APK:

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

Upload `app-release.aab` to Play Console → Production track.

## Verify the signed APK

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

The `Owner:` line should show `CN=Masjid Timings, OU=Konic IT, …`.

## Version bumping

Edit `pubspec.yaml`:

```yaml
version: 0.11.0+17    # → 0.11.1+18
#         ^^^^^^ ^^
#         |      build number (versionCode in Android — must always increase)
#         user-visible version (versionName)
```
