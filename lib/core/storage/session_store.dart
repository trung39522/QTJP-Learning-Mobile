import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStore {
  Future<String?> read(String server);
  Future<void> write(String server, String token);
  Future<void> clear();
}

/// Only the bearer token and its API origin are stored, never a password or
/// cached profile. The restored identity is always verified by the backend.
class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'qtjp.session.v1';
  @override
  Future<String?> read(String server) async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      final record = jsonDecode(value);
      if (record is Map &&
          record['server'] == server &&
          record['token'] is String &&
          (record['token'] as String).isNotEmpty) {
        return record['token'] as String;
      }
    } on FormatException {
      /* Delete a malformed record; never infer identity. */
    }
    await clear();
    return null;
  }

  @override
  Future<void> write(String server, String token) => _storage.write(
    key: _key,
    value: jsonEncode({'server': server, 'token': token}),
  );
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
