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

**⚠️ Known issue (2026-04-25):** With the current AGP 7.4.2 + Kotlin 1.9.22
combination, `--release` builds fail with `ERROR:D8: com.android.tools.r8.kotlin.H`
during dexing. The D8 dexer bundled with AGP 7.4.2 does not understand
the newer Kotlin metadata format. To fix, upgrade AGP and Gradle:

1. Edit `android/settings.gradle`:
   ```
   id "com.android.application" version "8.3.0" apply false   // was 7.4.2
   id "org.jetbrains.kotlin.android" version "1.9.22" apply false
   ```
2. Edit `android/gradle/wrapper/gradle-wrapper.properties`:
   ```
   distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-bin.zip
   ```
3. Run `cd android && ./gradlew wrapper --gradle-version 8.4`
4. Re-run `flutter build apk --release`

Until that upgrade, sideload the debug-signed APK from
`build/app/outputs/flutter-apk/app-release.apk` (which is signed with
the debug keystore but functionally identical for testing).

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
