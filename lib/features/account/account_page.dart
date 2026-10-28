import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services.dart';
import '../../shared/widgets.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.services});
  final AppServices services;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _busy = false;
  Future<void> perform(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) showMessage(context, safeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> export() async {
    final data = await widget.services.account.export();
    final directory = await Directory(
      '${(await getTemporaryDirectory()).path}/user-management-export',
    ).create();
    // Remove earlier exports rather than retaining account data indefinitely.
    await for (final item in directory.list()) {
      await item.delete(recursive: true);
    }
    final file = await File(
      '${directory.path}/personal-data.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    if (!mounted) {
      await file.delete();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'My personal data',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Widget build(BuildContext context) => ContentPage(
    title: 'Account & security',
    children: [
      Text(
        widget.services.session.user?.email ?? '',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 16),
      ListTile(
        leading: const Icon(Icons.password),
        title: const Text('Change password'),
        onTap: _busy ? null : () => context.push('/change-password'),
      ),
      ListTile(
        leading: const Icon(Icons.devices),
        title: const Text('Active sessions'),
        onTap: _busy ? null : () => context.push('/sessions'),
      ),
      SwitchListTile(
        title: const Text('Fingerprint / Face ID unlock'),
        subtitle: const Text(
          'Lock on startup and after 60 seconds in the background.',
        ),
        value: widget.services.session.biometricLock,
        onChanged: _busy
            ? null
            : (enabled) => perform(() async {
                if (await widget.services.authenticateLocally()) {
                  await widget.services.session.setBiometricLock(enabled);
                  if (mounted) setState(() {});
                } else if (context.mounted) {
                  showMessage(
                    context,
                    'Biometric verification is unavailable or was cancelled.',
                  );
                }
              }),
      ),
      ListTile(
        leading: const Icon(Icons.download_outlined),
        title: const Text('Export personal data'),
        subtitle: const Text(
          'Share a JSON file containing your account information.',
        ),
        onTap: _busy ? null : () => perform(export),
      ),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('Sign out this device'),
        onTap: _busy
            ? null
            : () => perform(() => widget.services.session.signOut()),
      ),
      ListTile(
        leading: const Icon(Icons.phonelink_erase),
        title: const Text('Sign out all devices'),
        onTap: _busy
            ? null
            : () => perform(() async {
                if (await confirmAction(
                  context,
                  'Sign out everywhere?',
                  'All active sessions, including this device, will be revoked.',
                )) {
                  await widget.services.session.signOut(all: true);
                }
              }),
      ),
      const Divider(),
      ListTile(
        leading: Icon(
          Icons.delete_forever,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Permanently delete account'),
        onTap: _busy ? null : () => context.push('/delete-account'),
      ),
      if (_busy) const LinearProgressIndicator(),
    ],
  );
}

class PasswordPage extends StatefulWidget {
  const PasswordPage({
    super.key,
    required this.services,
    this.deleteAccount = false,
  });
  final AppServices services;
  final bool deleteAccount;
  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(),
      _replacement = TextEditingController(),
      _confirm = TextEditingController();
  bool _busy = false, _confirmed = false;
  String? _error;
  @override
  void dispose() {
    _current.dispose();
    _replacement.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!_form.currentState!.validate() ||
        widget.deleteAccount && !_confirmed) {
      return;
    }
    if (widget.deleteAccount &&
        !await confirmAction(
          context,
          'Delete account permanently?',
          'Your profile, image and authentication sessions will be deleted. This cannot be undone.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.deleteAccount) {
        await widget.services.account.delete(_current.text);
      } else {
        await widget.services.account.changePassword(
          _current.text,
          _replacement.text,
        );
      }
      _current.clear();
      _replacement.clear();
      _confirm.clear();
      await widget.services.session.invalidate();
      if (mounted) context.go('/sign-in');
    } catch (error) {
      if (mounted) setState(() => _error = safeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget password(
    String label,
    TextEditingController controller,
    String? Function(String?) validator,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      enabled: !_busy,
      maxLength: 128,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) => ContentPage(
    title: widget.deleteAccount ? 'Delete account' : 'Change password',
    children: [
      InlineNotice(
        widget.deleteAccount
            ? 'Account deletion is permanent.'
            : 'Changing your password signs out every device.',
      ),
      Form(
        key: _form,
        child: Column(
          children: [
            password('Current password', _current, passwordText),
            if (!widget.deleteAccount) ...[
              password(
                'New password',
                _replacement,
                (value) =>
                    passwordText(value) ??
                    (value == _current.text
                        ? 'Choose a different password.'
                        : null),
              ),
              password(
                'Confirm new password',
                _confirm,
                (value) => value != _replacement.text
                    ? 'Passwords do not match.'
                    : null,
              ),
            ],
            if (widget.deleteAccount)
              CheckboxListTile(
                value: _confirmed,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _confirmed = value ?? false),
                title: const Text(
                  'I understand this permanently deletes my account.',
                ),
              ),
            if (_error != null) InlineNotice(_error!, error: true),
            FilledButton(
              onPressed: _busy || widget.deleteAccount && !_confirmed
                  ? null
                  : submit,
              child: Text(
                _busy
                    ? 'Please wait…'
                    : widget.deleteAccount
                    ? 'Delete my account'
                    : 'Change password',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
