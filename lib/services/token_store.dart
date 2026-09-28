// lib/services/token_store.dart
//
// Centralised storage for the JWT auth token, backed by the platform
// keystore (Android EncryptedSharedPreferences/Keystore, iOS Keychain) via
// flutter_secure_storage.
//
// Previously the token was kept in SharedPreferences, which on Android is a
// plaintext XML file under /data/data/<package>/shared_prefs/ - readable on
// a rooted device, and extractable without root via `adb backup` since the
// app did not set android:allowBackup="false". flutter_secure_storage keeps
// the value encrypted at rest and out of app backups.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  TokenStore._();

  static const _key = 'authToken';
  static const _storage = FlutterSecureStorage();

  static Future<void> save(String token) => _storage.write(key: _key, value: token);

  static Future<String?> read() => _storage.read(key: _key);

  static Future<void> clear() => _storage.delete(key: _key);
}
