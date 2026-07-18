import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ApiKeyStore {
  Future<String?> read();
  Future<void> write(String key);
}

class SecureApiKeyStore implements ApiKeyStore {
  const SecureApiKeyStore([this._storage = const FlutterSecureStorage()]);

  static const _key = 'api_key_openai';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      final value = await _storage.read(key: _key);
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key) async {
    final value = key.trim();
    if (value.isEmpty) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: value);
    }
  }
}

class InMemoryApiKeyStore implements ApiKeyStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String key) async {
    final value = key.trim();
    _value = value.isEmpty ? null : value;
  }
}
