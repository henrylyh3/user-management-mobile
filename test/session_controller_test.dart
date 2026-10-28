import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_management_mobile/core/api_client.dart';
import 'package:user_management_mobile/core/api_problem.dart';
import 'package:user_management_mobile/features/auth/session_controller.dart';
import 'package:user_management_mobile/features/auth/token_store.dart';

class MemoryStore implements TokenStore {
  String? token;
  bool biometric = false;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
    biometric = false;
  }

  @override
  Future<bool> biometricsEnabled() async => biometric;
  @override
  Future<void> setBiometrics(bool enabled) async {
    biometric = enabled;
  }
}

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handle);
  final Future<ResponseBody> Function(RequestOptions) handle;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handle(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody response(dynamic data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Map<String, dynamic> tokens(String suffix) => {
  'accessToken': 'test-access-$suffix',
  'refreshToken': 'test-refresh-$suffix',
  'sessionId': 'test-session',
  'accessTokenExpiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
  'refreshTokenExpiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(days: 7))
      .toIso8601String(),
};

const currentUser = {
  'userId': '012345678901234567890123',
  'email': 'test@example.com',
  'role': 'User',
  'isAuthenticated': true,
  'isAdmin': false,
};

void main() {
  late MemoryStore store;
  late ApiClient api;
  late SessionController session;
  late Future<ResponseBody> Function(RequestOptions) handler;
  setUp(() {
    store = MemoryStore();
    final dio = Dio()
      ..httpClientAdapter = FakeAdapter((options) => handler(options));
    api = ApiClient('https://api.example.test', transport: dio);
    session = SessionController(api, store);
  });
  tearDown(() {
    session.dispose();
    api.dio.close();
  });

  test(
    'Concurrent refresh callers share one rotation and persist replacement',
    () async {
      store.token = 'old-refresh';
      final entered = Completer<void>(), release = Completer<void>();
      var count = 0;
      handler = (options) async {
        expect(options.path, '/api/mobile/auth/refresh');
        expect(options.headers.containsKey('Authorization'), isFalse);
        count++;
        entered.complete();
        await release.future;
        return response(tokens('new'));
      };
      final first = session.refresh();
      await entered.future;
      final second = session.refresh();
      release.complete();
      await Future.wait([first, second]);
      expect(count, 1);
      expect(store.token, 'test-refresh-new');
    },
  );

  test('Refresh 401 clears credentials with no retry', () async {
    store.token = 'expired';
    var count = 0;
    handler = (_) async {
      count++;
      return response({}, 401);
    };
    await expectLater(session.refresh(), throwsA(isA<ApiProblem>()));
    expect(count, 1);
    expect(store.token, isNull);
    expect(session.state, SessionState.signedOut);
  });

  test('Ambiguous network failure discards old refresh token', () async {
    store.token = 'possibly-rotated';
    handler = (options) async => throw DioException(
      requestOptions: options,
      type: DioExceptionType.receiveTimeout,
    );
    await expectLater(session.refresh(), throwsA(isA<ApiProblem>()));
    expect(store.token, isNull);
  });

  test('Rate-limited refresh preserves credential and does not loop', () async {
    store.token = 'valid';
    var count = 0;
    handler = (_) async {
      count++;
      return response({}, 429);
    };
    await expectLater(session.refresh(), throwsA(isA<ApiProblem>()));
    expect(count, 1);
    expect(store.token, 'valid');
  });

  test('Late refresh cannot restore a locally invalidated session', () async {
    store.token = 'old';
    final entered = Completer<void>(), release = Completer<void>();
    handler = (_) async {
      entered.complete();
      await release.future;
      return response(tokens('late'));
    };
    final pending = session.refresh();
    final assertion = expectLater(pending, throwsA(isA<ApiProblem>()));
    await entered.future;
    await session.invalidate();
    release.complete();
    await assertion;
    expect(session.accessToken, isNull);
    expect(store.token, isNull);
    expect(session.state, SessionState.signedOut);
  });

  test(
    'Biometric startup does not read a token into an active session or call API',
    () async {
      store.token = 'saved';
      store.biometric = true;
      handler = (_) async {
        fail('API must not be called before local unlock');
      };
      await session.initialize();
      expect(session.state, SessionState.locked);
      expect(session.accessToken, isNull);
    },
  );

  test('Protected request replays at most once after refresh', () async {
    await session.invalidate();
    var protectedCalls = 0, refreshCalls = 0;
    handler = (options) async {
      if (options.path.endsWith('/signin')) return response(tokens('initial'));
      if (options.path.endsWith('/whoami')) return response(currentUser);
      if (options.path.endsWith('/refresh')) {
        refreshCalls++;
        return response(tokens('rotated'));
      }
      protectedCalls++;
      return response({}, 401);
    };
    await session.signIn('test@example.com', 'test-password', null);
    await expectLater(
      api.request('GET', '/api/User/012345678901234567890123'),
      throwsA(isA<ApiProblem>()),
    );
    expect(protectedCalls, 2);
    expect(refreshCalls, 1);
    expect(session.state, SessionState.signedOut);
  });

  test(
    'Signout waits for rotation and revokes the replacement token',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      String? revoked;
      handler = (options) async {
        if (options.path.endsWith('/signin')) {
          return response(tokens('initial'));
        }
        if (options.path.endsWith('/whoami')) return response(currentUser);
        if (options.path.endsWith('/refresh')) {
          entered.complete();
          await release.future;
          return response(tokens('latest'));
        }
        if (options.path.endsWith('/signout')) {
          revoked = (options.data as Map)['refreshToken'] as String;
          return response(null, 204);
        }
        fail('Unexpected endpoint');
      };
      await session.signIn('test@example.com', 'test-password', null);
      final refresh = session.refresh();
      await entered.future;
      final signout = session.signOut();
      release.complete();
      await Future.wait([refresh, signout]);
      expect(revoked, 'test-refresh-latest');
      expect(store.token, isNull);
    },
  );

  test('Stale 401 is not replayed under a replacement login', () async {
    final entered = Completer<void>(), release = Completer<void>();
    var calls = 0;
    handler = (options) async {
      if (options.path.endsWith('/signin')) return response(tokens('initial'));
      if (options.path.endsWith('/whoami')) return response(currentUser);
      calls++;
      entered.complete();
      await release.future;
      return response({}, 401);
    };
    await session.signIn('test@example.com', 'test-password', null);
    final pending = api.request('GET', '/api/User/012345678901234567890123');
    final assertion = expectLater(pending, throwsA(isA<ApiProblem>()));
    await entered.future;
    await session.invalidate();
    await session.signIn('other@example.com', 'test-password', null);
    release.complete();
    await assertion;
    expect(calls, 1);
    expect(session.state, SessionState.signedIn);
  });

  test('403 never triggers token refresh', () async {
    var refreshCalls = 0;
    handler = (options) async {
      if (options.path.endsWith('/signin')) return response(tokens('initial'));
      if (options.path.endsWith('/whoami')) return response(currentUser);
      if (options.path.endsWith('/refresh')) refreshCalls++;
      return response({}, 403);
    };
    await session.signIn('test@example.com', 'test-password', null);
    await expectLater(
      api.request('GET', '/api/User'),
      throwsA(isA<ApiProblem>()),
    );
    expect(refreshCalls, 0);
    expect(session.state, SessionState.signedIn);
  });
}
