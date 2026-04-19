// Backend base URL — points at the live API.
// For local dev against the Node backend on your laptop, use http://10.0.2.2:4011
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://masjid.eesa.co.in',
  );

  // Google Sign-In: this MUST be the WEB client ID (not the Android client ID).
  // The Android client identifies the app via package + SHA-1; the server client
  // ID tells Google to issue an ID token whose audience matches the backend.
  // Without this, GoogleSignIn returns an access token but no ID token.
  static const String googleServerClientId =
      '31201932680-iq1ctbg0r6ddvmrthbso0juntq73am6g.apps.googleusercontent.com';
}
