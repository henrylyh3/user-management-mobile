import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
  Future<bool> biometricsEnabled();
  Future<void> setBiometrics(bool enabled);
}

class SecureTokenStore implements TokenStore {
  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  static const _tokenKey = 'mobile.refresh_token';
  static const _biometricKey = 'mobile.biometric_unlock';

  @override
  Future<String?> read() => _storage.read(key: _tokenKey);
  @override
  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);
  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _biometricKey);
  }

  @override
  Future<bool> biometricsEnabled() async =>
      await _storage.read(key: _biometricKey) == 'true';
  @override
  Future<void> setBiometrics(bool enabled) =>
      _storage.write(key: _biometricKey, value: '$enabled');
}
