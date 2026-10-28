import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../shared/widgets.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key, required this.services});
  final AppServices services;
  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  bool _busy = false;
  Future<void> revoke(Map<String, dynamic> session, VoidCallback reload) async {
    if (!await confirmAction(
      context,
      'Revoke session?',
      session['isCurrent'] == true
          ? 'This will sign you out on this device.'
          : 'This device will need to sign in again.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final current = await widget.services.account.revoke(
        session['sessionId'] as String,
      );
      if (current) {
        await widget.services.session.invalidate();
      } else if (mounted) {
        reload();
      }
    } catch (error) {
      if (mounted) showMessage(context, safeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ContentPage(
    title: 'Active sessions',
    children: [
      if (_busy) const LinearProgressIndicator(),
      RemoteContent<List<Map<String, dynamic>>>(
        load: widget.services.account.sessions,
        builder: (items, reload) => Column(
          children: [
            if (items.isEmpty) const InlineNotice('No active sessions.'),
            for (final item in items)
              Card(
                child: ListTile(
                  leading: Icon(
                    item['isCurrent'] == true
                        ? Icons.phone_android
                        : Icons.devices,
                  ),
                  title: Text(
                    '${item['userAgent'] ?? 'Unknown device'}${item['isCurrent'] == true ? ' · This device' : ''}',
                  ),
                  subtitle: Text(
                    'IP: ${item['ipAddress'] ?? 'Unknown'}\nStarted: ${dateLabel(item['createdOn'])}\nLast active: ${dateLabel(item['lastSeenOn'])}\nExpires: ${dateLabel(item['expiresAt'])}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Revoke session',
                    onPressed: _busy ? null : () => revoke(item, reload),
                    icon: const Icon(Icons.logout),
                  ),
                ),
              ),
            OutlinedButton(
              onPressed: _busy ? null : reload,
              child: const Text('Refresh sessions'),
            ),
          ],
        ),
      ),
    ],
  );
}
