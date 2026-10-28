import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services.dart';
import 'coral_theme.dart';
import '../features/auth/auth_page.dart';
import '../features/auth/session_controller.dart';
import '../features/account/account_page.dart';
import '../features/account/profile_page.dart';
import '../features/admin_users/admin_users_page.dart';
import '../features/audit_events/audit_events_page.dart';
import '../features/sessions/sessions_page.dart';
import '../shared/widgets.dart';

class UserManagementApp extends ConsumerWidget {
  const UserManagementApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    if (config.error case final String error) {
      return MaterialApp(
        theme: coralTheme(),
        home: ContentPage(
          title: 'Setup required',
          children: [InlineNotice(error)],
        ),
      );
    }
    return _ConfiguredApp(services: ref.watch(servicesProvider));
  }
}

class _ConfiguredApp extends StatefulWidget {
  const _ConfiguredApp({required this.services});
  final AppServices services;
  @override
  State<_ConfiguredApp> createState() => _ConfiguredAppState();
}

class _ConfiguredAppState extends State<_ConfiguredApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  DateTime? _backgroundAt;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final services = widget.services;
    final session = services.session;
    const publicPaths = [
      '/sign-in',
      '/sign-up',
      '/forgot-password',
      '/reset-password',
      '/verify-email',
      '/resend-verification',
    ];
    _router = GoRouter(
      refreshListenable: session,
      redirect: (context, state) {
        final path = state.uri.path;
        final isPublic = publicPaths.contains(path);
        if (path == '/reset-password' || path == '/verify-email') return null;
        if (session.state == SessionState.starting) {
          return path == '/startup' ? null : '/startup';
        }
        if (session.state == SessionState.locked) {
          return path == '/unlock' ? null : '/unlock';
        }
        if (session.state == SessionState.signedOut) {
          return isPublic ? null : '/sign-in';
        }
        if (path == '/startup' || path == '/unlock' || isPublic) return '/';
        if ((path.startsWith('/users') || path == '/audit-events') &&
            session.user?.isAdmin != true) {
          return '/forbidden';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/startup',
          builder: (_, _) =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
        GoRoute(
          path: '/unlock',
          builder: (_, _) => _UnlockPage(services: services),
        ),
        GoRoute(
          path: '/sign-in',
          builder: (_, _) =>
              AuthPage(services: services, mode: AuthMode.signIn),
        ),
        GoRoute(
          path: '/sign-up',
          builder: (_, _) =>
              AuthPage(services: services, mode: AuthMode.signUp),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (_, _) =>
              AuthPage(services: services, mode: AuthMode.forgot),
        ),
        GoRoute(
          path: '/resend-verification',
          builder: (_, _) =>
              AuthPage(services: services, mode: AuthMode.resend),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (_, state) => AuthPage(
            key: const ValueKey('reset-password'),
            services: services,
            mode: AuthMode.reset,
            token: state.uri.queryParameters['token'],
          ),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (_, state) => AuthPage(
            key: const ValueKey('verify-email'),
            services: services,
            mode: AuthMode.verify,
            token: state.uri.queryParameters['token'],
          ),
        ),
        GoRoute(
          path: '/',
          builder: (_, _) => _HomePage(services: services),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, _) => ProfilePage(services: services),
        ),
        GoRoute(
          path: '/account',
          builder: (_, _) => AccountPage(services: services),
        ),
        GoRoute(
          path: '/sessions',
          builder: (_, _) => SessionsPage(services: services),
        ),
        GoRoute(
          path: '/change-password',
          builder: (_, _) => PasswordPage(services: services),
        ),
        GoRoute(
          path: '/delete-account',
          builder: (_, _) =>
              PasswordPage(services: services, deleteAccount: true),
        ),
        GoRoute(
          path: '/users',
          builder: (_, _) => AdminUsersPage(services: services),
        ),
        GoRoute(
          path: '/users/:id',
          builder: (_, state) => ProfilePage(
            services: services,
            userId: state.pathParameters['id'],
          ),
        ),
        GoRoute(
          path: '/audit-events',
          builder: (_, _) => AuditEventsPage(services: services),
        ),
        GoRoute(
          path: '/forbidden',
          builder: (_, _) => const ContentPage(
            title: 'Access denied',
            children: [
              InlineNotice('You do not have permission to view this screen.'),
            ],
          ),
        ),
      ],
      errorBuilder: (_, _) => const ContentPage(
        title: 'Page not found',
        children: [InlineNotice('This page does not exist.')],
      ),
    );
    unawaited(session.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundAt ??= DateTime.now();
    }
    if (state == AppLifecycleState.resumed) {
      if (_backgroundAt != null &&
          DateTime.now().difference(_backgroundAt!) >=
              const Duration(seconds: 60)) {
        widget.services.session.lock();
      }
      _backgroundAt = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'User Management',
    debugShowCheckedModeBanner: false,
    routerConfig: _router,
    theme: coralTheme(),
  );
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.services});
  final AppServices services;
  @override
  Widget build(BuildContext context) => ContentPage(
    title: 'User Management',
    children: [
      Text(
        'Your account, in your hands.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      Text(services.session.user?.email ?? ''),
      const SizedBox(height: 24),
      for (final entry in [
        (
          'My profile',
          'View and edit your personal details',
          Icons.account_circle_outlined,
          '/profile',
        ),
        (
          'Account & security',
          'Password, biometrics, export and deletion',
          Icons.shield_outlined,
          '/account',
        ),
        (
          'Active sessions',
          'See and manage signed-in devices',
          Icons.devices_outlined,
          '/sessions',
        ),
        if (services.session.user?.isAdmin == true) ...[
          (
            'Manage users',
            'Roles, access and account status',
            Icons.group_outlined,
            '/users',
          ),
          (
            'Audit events',
            'Review account and security activity',
            Icons.history_outlined,
            '/audit-events',
          ),
        ],
      ])
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Icon(entry.$3),
            title: Text(entry.$1),
            subtitle: Text(entry.$2),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(entry.$4),
          ),
        ),
    ],
  );
}

class _UnlockPage extends StatefulWidget {
  const _UnlockPage({required this.services});
  final AppServices services;
  @override
  State<_UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<_UnlockPage> {
  bool _busy = false;
  String? _error;
  Future<void> unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!widget.services.session.biometricLock ||
          await widget.services.authenticateLocally()) {
        await widget.services.session.restore();
      } else if (mounted) {
        setState(
          () => _error =
              'Unlock cancelled or biometrics unavailable. You can sign in with your password.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = safeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ContentPage(
    title: 'Unlock your session',
    children: [
      const Icon(Icons.fingerprint, size: 80),
      const SizedBox(height: 24),
      if ((_error ?? widget.services.session.startupError)
          case final String message)
        InlineNotice(message, error: true),
      FilledButton(
        onPressed: _busy ? null : unlock,
        child: Text(
          _busy
              ? 'Unlocking…'
              : widget.services.session.biometricLock
              ? 'Unlock with biometrics'
              : 'Retry session restoration',
        ),
      ),
      TextButton(
        onPressed: _busy
            ? null
            : () async {
                try {
                  await widget.services.session.invalidate();
                } catch (_) {
                  if (context.mounted) {
                    showMessage(
                      context,
                      'Unable to clear secure storage. Try again.',
                    );
                  }
                }
              },
        child: const Text('Sign in with password instead'),
      ),
    ],
  );
}
