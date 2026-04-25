# Play Store Listing — Masjid Timings

Use this content when filling out the Google Play Console listing for the
**Masjid Timings** app.

---

## Short description (80 chars max)

> Daily prayer times for 70+ masjids in Nellore, with announcements and alerts.

## Full description (4000 chars max)

> 🕌 **Masjid Timings** is the easiest way to find prayer times at masjids
> across Nellore, Andhra Pradesh.
>
> ✨ **Features**
>
> 📍 **Find your nearest masjid** — open the app and instantly see masjids
> in Nellore sorted by distance from where you are. View prayer timings
> (Fajr, Dhuhr, Asr, Maghrib, Isha) and Friday Jumu'ah for each.
>
> 🔔 **Prayer reminders** — get notified before adhan and at jamaat time
> for the masjid you choose. Pick how many minutes before, which prayers,
> all on-device — no data needed once set up.
>
> 🧭 **Directions** — one tap opens Google Maps navigation to any masjid.
>
> 📤 **Share masjid details** — share name, address, and Google Maps
> location with anyone via WhatsApp, SMS, etc.
>
> ❤️ **Favourites** — star the masjids you visit most for quick access.
>
> 📢 **Announcements** — get city-wide notices for Janaza prayers, Eid
> prayer schedules, special prayers like Taraweeh, with verified timings.
>
> 🛡️ **Verified prayer times** — every masjid is updated by its own
> admin. Each entry shows when it was last verified, with clear "outdated"
> warnings if not updated recently.
>
> ⏱️ **Live next-prayer countdown** — the home screen shows the next
> prayer at your nearest masjid, with a live countdown timer.
>
> 🆓 **100% free, no ads, no tracking** — built by the Nellore Muslim
> community, for the Nellore Muslim community.
>
> ---
>
> **For masjid administrators:**
>
> Admins of any Nellore masjid can sign in to update timings, post
> announcements (Janaza, Eid, Special Prayers), approve member
> registrations, and verify their masjid's prayer times. Use the
> "Use my location" button while standing at the masjid to capture
> precise GPS coordinates.
>
> **Coverage:** Currently 70+ masjids across Nellore city. If you're a
> masjid admin and your masjid isn't listed, please contact us at
> mdaneesahmed@gmail.com.

## Category

**Lifestyle** (primary), **Tools** (secondary)

## Content rating

**Everyone**

## Tags / keywords

masjid, mosque, prayer times, nellore, namaz, salah, adhan, athan,
islamic, muslim, qibla, jumuah, jamaat, andhra pradesh

## Contact details

- **Email:** mdaneesahmed@gmail.com
- **Website:** https://masjid.eesa.co.in
- **Privacy policy URL:** https://masjid.eesa.co.in/privacy (host the
  PRIVACY_POLICY.md content here)

## App access (data safety questions)

- ✅ Location — used only locally to sort masjids by distance and
  optionally for admins to capture GPS coordinates of a masjid they manage
- ✅ Personal info — name, email, phone collected at sign-in for
  membership and notifications
- ✅ Photos and videos — none
- ✅ Files and docs — none
- ✅ Calendar / contacts — none
- ✅ Microphone / camera — none
- ✅ Notifications — local prayer reminders only (no push)
- ❌ Data shared with third parties — NO
- ❌ Data sold to third parties — NO

## Required graphics for the listing

You'll need to upload these in Play Console (placeholders not provided here):

- **App icon** — `android/app/src/main/ic_launcher-playstore.png`
  (already 512×512, generated from `LogoGenerator.java`)
- **Feature graphic** — 1024×500 banner (need to design separately)
- **Phone screenshots** — minimum 2, max 8, 16:9 aspect, 1080×1920 typical
  (need actual device screenshots)
- **(Optional) Tablet screenshots** — same format, 7" or 10"

## Pre-launch checklist

- [ ] Sign up for a Google Play Console account ($25 one-time)
- [ ] Build a release **AAB** (Android App Bundle), not just an APK:
      `flutter build appbundle --release` — output at
      `build/app/outputs/bundle/release/app-release.aab`
- [ ] Upload the SHA-1 of your **upload keystore** (NOT the debug one)
      to your Google Cloud OAuth Android client. Get it with:
      `keytool -list -v -keystore android/app/upload-keystore.jks`
- [ ] Add the privacy policy URL to the listing
- [ ] Fill in the Data Safety form using the bullets above
- [ ] Submit for review (Google takes 1-7 days for first review)
