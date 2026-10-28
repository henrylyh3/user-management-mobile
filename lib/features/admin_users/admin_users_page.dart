import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services.dart';
import '../../shared/widgets.dart';
import '../account/account_repository.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, required this.services});
  final AppServices services;
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  int _page = 1;
  bool _busy = false;
  Future<void> mutate(
    Map<String, dynamic> user,
    String action,
    VoidCallback reload,
  ) async {
    final value = switch (action) {
      'role' => user['role'] == 'Admin' ? 'User' : 'Admin',
      'status' => user['status'] == 'Active' ? 'Disabled' : 'Active',
      _ => null,
    };
    if (!await confirmAction(
      context,
      'Confirm user change',
      action == 'unlock'
          ? 'Unlock ${user['email']}?'
          : 'Change ${user['email']} $action to $value?',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await widget.services.account.adminMutation(
        user['id'] as String,
        action,
        value,
      );
      if (mounted) {
        reload();
        showMessage(context, 'User updated.');
      }
    } catch (error) {
      if (mounted) showMessage(context, safeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ContentPage(
    title: 'User management',
    children: [
      if (_busy) const LinearProgressIndicator(),
      RemoteContent<PagedItems>(
        key: ValueKey(_page),
        load: () => widget.services.account.users(_page),
        builder: (result, reload) => Column(
          children: [
            if (result.items.isEmpty) const InlineNotice('No users found.'),
            for (final user in result.items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${user['firstName']} ${user['lastName']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('${user['email']}'),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text('${user['role']}')),
                          Chip(label: Text('${user['status']}')),
                          if (user['isLockedOut'] == true)
                            const Chip(label: Text('Locked')),
                        ],
                      ),
                      Text('Last sign in: ${dateLabel(user['lastSignInOn'])}'),
                      TextButton(
                        onPressed: () => context.push(
                          '/users/${Uri.encodeComponent(user['id'] as String)}',
                        ),
                        child: const Text('View / edit profile'),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed:
                                _busy ||
                                    user['id'] ==
                                        widget.services.session.user?.id
                                ? null
                                : () => mutate(user, 'role', reload),
                            child: Text(
                              user['role'] == 'Admin'
                                  ? 'Make User'
                                  : 'Make Admin',
                            ),
                          ),
                          OutlinedButton(
                            onPressed:
                                _busy ||
                                    user['id'] ==
                                        widget.services.session.user?.id
                                ? null
                                : () => mutate(user, 'status', reload),
                            child: Text(
                              user['status'] == 'Active' ? 'Disable' : 'Enable',
                            ),
                          ),
                          if (user['isLockedOut'] == true)
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => mutate(user, 'unlock', reload),
                              child: const Text('Unlock'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _page <= 1 || _busy
                      ? null
                      : () => setState(() => _page--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  'Page $_page of ${result.totalPages == 0 ? 1 : result.totalPages}',
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: _page >= result.totalPages || _busy
                      ? null
                      : () => setState(() => _page++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            TextButton(
              onPressed: _busy ? null : reload,
              child: const Text('Refresh users'),
            ),
          ],
        ),
      ),
    ],
  );
}
