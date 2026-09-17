import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<String?> readEmail();
  Future<void> save({
    required String access,
    required String refresh,
    required String email,
  });
  Future<void> clear();
}

class MemoryTokenStore implements TokenStore {
  String? access;
  String? refresh;
  String? email;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<void> save({
    required String access,
    required String refresh,
    required String email,
  }) async {
    this.access = access;
    this.refresh = refresh;
    this.email = email;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
    email = null;
  }
}

class SecureTokenStore implements TokenStore {
  static const _accessKey = 'athkar.access';
  static const _refreshKey = 'athkar.refresh';
  static const _emailKey = 'athkar.email';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> readAccess() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  @override
  Future<String?> readEmail() => _storage.read(key: _emailKey);

  @override
  Future<void> save({
    required String access,
    required String refresh,
    required String email,
  }) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
    await _storage.write(key: _emailKey, value: email);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _emailKey);
  }
}
