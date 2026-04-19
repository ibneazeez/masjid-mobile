# masjid-mobile

Flutter app for **Masjids of Nellore** — companion to `masjid-backend` (`masjid.eesa.co.in`).

## Features

- Browse as Guest — no login needed for masjid search & timings
- GPS-sorted masjid list (nearest first)
- Per-masjid prayer timings (Fajr, Dhuhr, Asr, Maghrib, Isha, Jumu'ah)
- Sign in / register / become a member (approval by admin)
- Per-masjid roles displayed in profile

## Build APK

```bash
flutter pub get
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

To point at a different backend (e.g. local dev):

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:4011
```

Default base URL is `https://masjid.eesa.co.in` (set in `lib/config.dart`).
