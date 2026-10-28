import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/api_problem.dart';
import 'session_tokens.dart';
import 'token_store.dart';

enum SessionState { starting, signedOut, locked, signedIn }

class SessionController extends ChangeNotifier implements AccessSession {
  SessionController(this.api, this.store) {
    api.session = this;
  }
  final ApiClient api;
  final TokenStore store;
  SessionState state = SessionState.starting;
  CurrentUser? user;
  SessionTokens? _tokens;
  Future<void>? _refreshing;
  Future<void> _storageTail = Future<void>.value();
  int _generation = 0;
  @override
  int get generation => _generation;
  bool biometricLock = false;
  String? startupError;
  @override
  String? get accessToken =>
      state == SessionState.locked ? null : _tokens?.accessToken;

  Future<void> initialize() async {
    try {
      biometricLock = await store.biometricsEnabled();
      if (await store.read() == null) {
        state = SessionState.signedOut;
      } else if (biometricLock) {
        state = SessionState.locked;
      } else {
        await restore();
      }
    } catch (_) {
      if (state != SessionState.signedOut) {
        startupError =
            'Your session could not be restored. Retry or sign in again.';
        state = SessionState.locked;
      }
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password, String? captcha) async {
    final generation = ++_generation;
    final result = await api.request(
      'POST',
      '/api/mobile/auth/signin',
      authenticated: false,
      data: {
        'email': email.trim(),
        'password': password,
        'keepMeSignedIn': true,
        'captchaToken': captcha,
      },
    );
    await _accept(result, generation);
    await _loadUser();
  }

  Future<void> _accept(dynamic result, int generation) async {
    final tokens = SessionTokens.fromJson(result);
    if (generation != _generation) {
      throw const ApiProblem('The session has changed. Please sign in again.');
    }
    // Store rotated credentials before allowing queued requests to continue.
    try {
      await _mutateStorage(() async {
        if (generation != _generation) {
          throw const ApiProblem(
            'The session has changed. Please sign in again.',
          );
        }
        await store.write(tokens.refreshToken);
      });
    } on ApiProblem {
      rethrow;
    } catch (_) {
      if (generation == _generation) await invalidate();
      throw const ApiProblem(
        'Secure storage is unavailable. Please sign in again.',
      );
    }
    if (generation != _generation) {
      throw const ApiProblem('The session has changed. Please sign in again.');
    }
    _tokens = tokens;
  }

  Future<void> _mutateStorage(Future<void> Function() operation) {
    final result = _storageTail.then((_) => operation());
    _storageTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _loadUser() async {
    final generation = _generation;
    final current = CurrentUser.fromJson(
      await api.request('GET', '/api/auth/whoami'),
    );
    if (generation != _generation) return;
    user = current;
    state = SessionState.signedIn;
    startupError = null;
    notifyListeners();
  }

  Future<void> restore() async {
    // Called only after biometric verification when biometric locking is enabled.
    state = SessionState.starting;
    try {
      await refresh();
      await _loadUser();
    } catch (_) {
      if (state != SessionState.signedOut) state = SessionState.locked;
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> refresh() {
    if (state == SessionState.locked) {
      throw const ApiProblem('Unlock your session first.');
    }
    return _refreshing ??= _rotate().whenComplete(() => _refreshing = null);
  }

  Future<void> _rotate() async {
    final generation = _generation;
    final token = await store.read();
    if (token == null) {
      await invalidate();
      throw const ApiProblem('Please sign in again.', status: 401);
    }
    try {
      final result = await api.request(
        'POST',
        '/api/mobile/auth/refresh',
        authenticated: false,
        data: {'refreshToken': token},
      );
      await _accept(result, generation);
    } on ApiProblem catch (error) {
      // A lost refresh response may mean the old token has already rotated.
      // Do not send it again and trigger account-wide reuse detection.
      if (error.status != 429 && generation == _generation) await invalidate();
      rethrow;
    } catch (_) {
      if (generation == _generation) await invalidate();
      throw const ApiProblem(
        'The session could not be renewed. Please sign in again.',
      );
    }
  }

  void lock() {
    if (!biometricLock || state != SessionState.signedIn) return;
    state = SessionState.locked;
    _tokens = null;
    user = null;
    notifyListeners();
  }

  Future<void> setBiometricLock(bool enabled) async {
    await store.setBiometrics(enabled);
    biometricLock = enabled;
    notifyListeners();
  }

  Future<void> signOut({bool all = false}) async {
    // Revoke the latest rotated credential, not an already replaced token.
    final pending = _refreshing;
    if (pending != null) await pending;
    if (all) {
      await api.request('POST', '/api/mobile/auth/signout-all');
    } else {
      final token = await store.read();
      if (token != null) {
        await api.request(
          'POST',
          '/api/mobile/auth/signout',
          authenticated: false,
          data: {'refreshToken': token},
        );
      }
    }
    await invalidate();
  }

  @override
  Future<void> invalidate() async {
    _generation++;
    _tokens = null;
    user = null;
    state = SessionState.signedOut;
    biometricLock = false;
    notifyListeners();
    await _mutateStorage(store.clear);
  }
}
