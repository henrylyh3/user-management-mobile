import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_problem.dart';
import '../../core/services.dart';
import '../../shared/widgets.dart';
import 'captcha_page.dart';
import 'coral_sign_in.dart';

enum AuthMode { signIn, signUp, forgot, reset, verify, resend }

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.services,
    required this.mode,
    this.token,
  });
  final AppServices services;
  final AuthMode mode;
  final String? token;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false, _captchaRequired = false;
  String? _error, _success;
  int _cooldown = 0;
  Timer? _timer;

  String get title => switch (widget.mode) {
    AuthMode.signIn => 'Welcome back',
    AuthMode.signUp => 'Create your account',
    AuthMode.forgot => 'Forgot password',
    AuthMode.reset => 'Reset password',
    AuthMode.verify => 'Verify email',
    AuthMode.resend => 'Resend verification',
  };
  @override
  void didUpdateWidget(covariant AuthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token || oldWidget.mode != widget.mode) {
      _success = null;
      _error = null;
      _password.clear();
      _confirm.clear();
    }
  }

  @override
  void dispose() {
    for (final controller in [_email, _password, _first, _last, _confirm]) {
      controller.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void cooldown() {
    _cooldown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> submit() async {
    if (!_form.currentState!.validate()) return;
    if ([AuthMode.reset, AuthMode.verify].contains(widget.mode) &&
        (widget.token == null ||
            widget.token!.isEmpty ||
            widget.token!.length > 256)) {
      setState(
        () => _error = 'This email link is invalid. Request a new link.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      String? captcha;
      if (widget.mode == AuthMode.forgot || _captchaRequired) {
        captcha = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => CaptchaPage(
              pageUrl: widget.services.config.challengeUrl,
              action: widget.mode == AuthMode.forgot
                  ? 'forgot_password'
                  : 'signin',
            ),
          ),
        );
        if (captcha == null) return;
      }
      if (widget.mode == AuthMode.signIn) {
        await widget.services.session.signIn(
          _email.text,
          _password.text,
          captcha,
        );
        _password.clear();
        if (mounted) context.go('/');
        return;
      }
      final (path, data, message) = switch (widget.mode) {
        AuthMode.signUp => (
          '/api/auth/signup',
          <String, dynamic>{
            'firstName': _first.text.trim(),
            'lastName': _last.text.trim(),
            'email': _email.text.trim(),
            'password': _password.text,
          },
          'Check your email to verify your account before signing in.',
        ),
        AuthMode.forgot => (
          '/api/account/forgot-password',
          <String, dynamic>{
            'email': _email.text.trim(),
            'captchaToken': captcha,
          },
          'If the account exists, a password reset link will be emailed.',
        ),
        AuthMode.resend => (
          '/api/account/resend-verification',
          <String, dynamic>{'email': _email.text.trim()},
          'If verification is needed, a new link will be emailed.',
        ),
        AuthMode.reset => (
          '/api/account/reset-password',
          <String, dynamic>{
            'token': widget.token,
            'newPassword': _password.text,
          },
          'Password reset. Sign in with your new password.',
        ),
        AuthMode.verify => (
          '/api/account/verify-email',
          <String, dynamic>{'token': widget.token},
          'Email verified. You can now sign in.',
        ),
        AuthMode.signIn => throw StateError('Handled above'),
      };
      await widget.services.api.request(
        'POST',
        path,
        data: data,
        authenticated: false,
      );
      if (widget.mode == AuthMode.reset) {
        await widget.services.session.invalidate();
      }
      _password.clear();
      _confirm.clear();
      if (mounted) {
        setState(() {
          _success = message;
          if ([
            AuthMode.resend,
            AuthMode.forgot,
            AuthMode.signUp,
          ].contains(widget.mode)) {
            cooldown();
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = safeError(error);
          if (error is ApiProblem) {
            _captchaRequired =
                error.captchaRequired ||
                error.code == 'captcha_required' ||
                _captchaRequired;
            if (error.status == 429) cooldown();
            if (error.errors.isNotEmpty) {
              _error = error.errors.values.expand((v) => v).join('\n');
            }
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget field(
    String label,
    TextEditingController controller,
    String? Function(String?) validator, {
    bool secret = false,
    bool email = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      validator: validator,
      obscureText: secret,
      enabled: !_busy,
      autocorrect: !secret && !email,
      enableSuggestions: !secret,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      maxLength: secret
          ? 128
          : email
          ? 254
          : 100,
    ),
  );

  @override
  Widget build(BuildContext context) => widget.mode == AuthMode.signIn
      ? _signIn()
      : ContentPage(
          title: title,
          children: [
            const Icon(Icons.manage_accounts_outlined, size: 56),
            const SizedBox(height: 24),
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.mode == AuthMode.signUp) ...[
                    field('First name', _first, nameText),
                    field('Last name', _last, nameText),
                  ],
                  if (![AuthMode.reset, AuthMode.verify].contains(widget.mode))
                    field('Email', _email, emailText, email: true),
                  if ([
                    AuthMode.signIn,
                    AuthMode.signUp,
                    AuthMode.reset,
                  ].contains(widget.mode))
                    field(
                      widget.mode == AuthMode.reset
                          ? 'New password'
                          : 'Password',
                      _password,
                      passwordText,
                      secret: true,
                    ),
                  if ([AuthMode.signUp, AuthMode.reset].contains(widget.mode))
                    field(
                      'Confirm password',
                      _confirm,
                      (value) => value != _password.text
                          ? 'Passwords do not match.'
                          : null,
                      secret: true,
                    ),
                  if (widget.mode == AuthMode.signIn)
                    const Text(
                      'Your session stays signed in on this device until it expires or you sign out.',
                    ),
                  if (widget.mode == AuthMode.verify)
                    const Text(
                      'Confirm to verify the email address from your link.',
                    ),
                  if (_error != null) InlineNotice(_error!, error: true),
                  if (_success != null) InlineNotice(_success!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || _cooldown > 0 ? null : submit,
                    child: Text(
                      _busy
                          ? 'Please wait…'
                          : _cooldown > 0
                          ? 'Try again in ${_cooldown}s'
                          : _captchaRequired || widget.mode == AuthMode.forgot
                          ? 'Verify and continue'
                          : title,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (widget.mode != AuthMode.signIn)
              TextButton(
                onPressed: () => context.go('/sign-in'),
                child: const Text('Back to sign in'),
              ),
            if (widget.mode == AuthMode.signIn) ...[
              TextButton(
                onPressed: () => context.go('/sign-up'),
                child: const Text('Create an account'),
              ),
              TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: const Text('Forgot password?'),
              ),
              TextButton(
                onPressed: () => context.go('/resend-verification'),
                child: const Text('Resend verification email'),
              ),
            ],
          ],
        );

  Widget _signIn() => CoralSignIn(
    title: title,
    form: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field('Email', _email, emailText, email: true),
          field('Password', _password, requiredText, secret: true),
          const Text(
            'Your session stays signed in on this device until it expires or you sign out.',
          ),
          if (_error != null) InlineNotice(_error!, error: true),
          if (_success != null) InlineNotice(_success!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _cooldown > 0 ? null : submit,
            child: Text(
              _busy
                  ? 'Please wait…'
                  : _cooldown > 0
                  ? 'Try again in ${_cooldown}s'
                  : _captchaRequired
                  ? 'Verify and continue'
                  : title,
            ),
          ),
        ],
      ),
    ),
    navigation: [
      OutlinedButton(
        onPressed: () => context.go('/sign-up'),
        child: const Text('Create an account'),
      ),
      OutlinedButton(
        onPressed: () => context.go('/forgot-password'),
        child: const Text('Forgot password?'),
      ),
      OutlinedButton(
        onPressed: () => context.go('/resend-verification'),
        child: const Text('Resend verification email'),
      ),
    ],
  );
}
