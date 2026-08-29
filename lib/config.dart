// lib/config.dart
//
// Central configuration for the AIM-Lift mobile app.
//
// [apiBaseUrl] defaults to the deployed cloud backend. Override it for local
// development at run/build time (no need to edit this file):
//
//   Cloud (default):            https://aim-lift.onrender.com/api
//   Local - Android emulator:   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
//   Local - iOS simulator:      flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
//   Local - physical device:    flutter run --dart-define=API_BASE_URL=http://<your-PC-LAN-IP>:8000/api

class AppConfig {
  /// Base URL for all backend API calls, WITHOUT a trailing slash.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://aim-lift.onrender.com/api',
  );
}
