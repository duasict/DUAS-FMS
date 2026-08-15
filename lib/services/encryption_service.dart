import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  EncryptionService._();

  // Primary storage: EncryptedSharedPreferences (AES-256 + Keystore master key)
  static const _primary = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Fallback: plain Keystore-backed storage without EncryptedSharedPreferences.
  // Used when the Jetpack Security library fails to initialise (some OEM ROMs,
  // work-profile sandboxes, or Keystores invalidated after OS update).
  static const _fallback = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
  );

  static const _keyAlias = 'uas_fms_db_key_v1';

  static String _generateKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Returns the database encryption key, creating and persisting it on first
  /// call.  Tries EncryptedSharedPreferences first; if the device's Keystore
  /// rejects it falls back to plain Keystore-backed storage.
  static Future<String> getDatabaseKey() async {
    // ── Try primary storage (EncryptedSharedPreferences) ────────────────────
    try {
      final existing = await _primary.read(key: _keyAlias);
      if (existing != null && existing.length == 64) return existing;
      final key = _generateKey();
      await _primary.write(key: _keyAlias, value: key);
      return key;
    } catch (e) {
      debugPrint('[EncryptionService] primary storage failed, trying fallback: $e');
    }

    // ── Fallback: plain Keystore storage ─────────────────────────────────────
    try {
      final existing = await _fallback.read(key: _keyAlias);
      if (existing != null && existing.length == 64) return existing;
      // Also migrate a key previously written by primary if possible
      String? migrated;
      try { migrated = await _primary.read(key: _keyAlias); } catch (_) {}
      final key = (migrated != null && migrated.length == 64)
          ? migrated
          : _generateKey();
      await _fallback.write(key: _keyAlias, value: key);
      return key;
    } catch (e) {
      debugPrint('[EncryptionService] fallback storage also failed: $e');
      throw Exception(
        'Device secure storage is unavailable. '
        'This app cannot run without Android Keystore support.',
      );
    }
  }

  static Future<void> clearKey() async {
    try { await _primary.delete(key: _keyAlias); } catch (_) {}
    try { await _fallback.delete(key: _keyAlias); } catch (_) {}
  }
}
