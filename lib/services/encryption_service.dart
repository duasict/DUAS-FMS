import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  EncryptionService
//
//  Manages the SQLite database encryption key.
//
//  • The key is a 64-character hex string (32 random bytes).
//  • It is generated once and stored in the platform's secure storage
//    (Keystore on Android, Keychain on iOS).
//  • The same key is returned on every subsequent call — the DB can only
//    be opened on the device that generated it.
// ─────────────────────────────────────────────────────────────────────────────

class EncryptionService {
  EncryptionService._();

  static const _storage  = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyAlias = 'uas_fms_db_key_v1';

  /// Returns the database encryption key, generating and persisting it if this
  /// is the first call on this device.
  static Future<String> getDatabaseKey() async {
    final existing = await _storage.read(key: _keyAlias);
    if (existing != null && existing.length == 64) return existing;

    // Generate a cryptographically random 32-byte key, encoded as hex
    final rng      = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final key      =
        keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _keyAlias, value: key);
    return key;
  }

  /// Wipes the stored key — only call this when intentionally resetting app data.
  static Future<void> clearKey() =>
      _storage.delete(key: _keyAlias);
}
