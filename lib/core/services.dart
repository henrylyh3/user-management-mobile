import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../features/auth/session_controller.dart';
import '../features/auth/token_store.dart';
import '../features/account/account_repository.dart';
import 'api_client.dart';
import 'config.dart';

final configProvider = Provider((ref) => AppConfig.environment());
final servicesProvider = Provider((ref) {
  final config = ref.watch(configProvider);
  final api = ApiClient(config.apiUrl);
  final session = SessionController(api, SecureTokenStore());
  ref.onDispose(() {
    session.dispose();
    api.dio.close();
  });
  return AppServices(config, api, session);
});

class AppServices {
  AppServices(this.config, this.api, this.session)
    : account = AccountRepository(api);
  final AppConfig config;
  final ApiClient api;
  final SessionController session;
  final AccountRepository account;
  final localAuth = LocalAuthentication();

  Future<bool> authenticateLocally() async {
    if (!await localAuth.canCheckBiometrics ||
        !await localAuth.isDeviceSupported()) {
      return false;
    }
    return localAuth.authenticate(
      localizedReason: 'Unlock your User Management session',
      biometricOnly: true,
    );
  }
}
