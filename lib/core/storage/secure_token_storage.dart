import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Contract for persistent, hardware-backed authentication token storage.
abstract class SecureTokenStorage {
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> deleteToken();
  Future<bool> hasToken();

  Future<void> saveUserData(Map<String, dynamic> user);
  Future<Map<String, dynamic>?> getUserData();
  Future<void> deleteUserData();

  Future<void> clearAll();
}

/// Implementation of [SecureTokenStorage] backed by [FlutterSecureStorage].
class SecureTokenStorageImpl implements SecureTokenStorage {
  static const String _tokenKey = 'alameen_sanctum_token';
  static const String _userDataKey = 'alameen_user_profile';

  final FlutterSecureStorage _storage;

  SecureTokenStorageImpl({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  @override
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      // In case of platform keystore invalidation or decryption error, clear corrupt entry
      await _storage.delete(key: _tokenKey);
      return null;
    }
  }

  @override
  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  @override
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.trim().isNotEmpty;
  }

  @override
  Future<void> saveUserData(Map<String, dynamic> user) async {
    final jsonStr = jsonEncode(user);
    await _storage.write(key: _userDataKey, value: jsonStr);
  }

  @override
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final jsonStr = await _storage.read(key: _userDataKey);
      if (jsonStr == null || jsonStr.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      await _storage.delete(key: _userDataKey);
      return null;
    }
  }

  @override
  Future<void> deleteUserData() async {
    await _storage.delete(key: _userDataKey);
  }

  @override
  Future<void> clearAll() async {
    await Future.wait([
      deleteToken(),
      deleteUserData(),
    ]);
  }
}
