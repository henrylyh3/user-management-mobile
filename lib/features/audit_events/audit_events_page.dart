import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../shared/widgets.dart';
import '../account/account_repository.dart';

class AuditEventsPage extends StatefulWidget {
  const AuditEventsPage({super.key, required this.services});
  final AppServices services;
  @override
  State<AuditEventsPage> createState() => _AuditEventsPageState();
}

class _AuditEventsPageState extends State<AuditEventsPage> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'module',
      'action',
      'actorUserId',
      'resourceType',
      'resourceId',
      'from',
      'to',
    ])
      key: TextEditingController(),
  };
  final _labels = {
    'module': 'Module',
    'action': 'Action',
    'actorUserId': 'Actor user ID',
    'resourceType': 'Resource type',
    'resourceId': 'Resource ID',
    'from': 'From (ISO 8601 date/time)',
    'to': 'To (ISO 8601 date/time)',
  };
  Map<String, String> _filters = {};
  String _outcome = '';
  int _page = 1, _revision = 0;
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String? validate(String key, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (key == 'actorUserId' &&
        !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value.trim())) {
      return 'Enter a 24-character user ID.';
    }
    if (key == 'from' || key == 'to') {
      if (DateTime.tryParse(value) == null) {
        return 'Enter an ISO 8601 date/time.';
      }
      final from = DateTime.tryParse(_fields['from']!.text),
          to = DateTime.tryParse(_fields['to']!.text);
      if (from != null && to != null && from.isAfter(to)) {
        return 'From must be earlier than To.';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => ContentPage(
    title: 'Audit events',
    children: [
      ExpansionTile(
        key: ValueKey('filters-$_revision'),
        title: const Text('Filter events'),
        children: [
          Form(
            key: _form,
            child: Column(
              children: [
                for (final entry in _fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        labelText: _labels[entry.key],
                      ),
                      validator: (value) => validate(entry.key, value),
                      maxLength: entry.key == 'resourceId' ? 128 : 64,
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _outcome,
                  decoration: const InputDecoration(labelText: 'Outcome'),
                  items: [
                    for (final value in ['', 'Success', 'Failure', 'Denied'])
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.isEmpty ? 'All outcomes' : value),
                      ),
                  ],
                  onChanged: (value) => _outcome = value ?? '',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    if (!_form.currentState!.validate()) return;
                    setState(() {
                      _page = 1;
                      _revision++;
                      _filters = {
                        for (final entry in _fields.entries)
                          entry.key: entry.value.text.trim(),
                        'outcome': _outcome,
                      };
                      for (final key in ['from', 'to']) {
                        final date = DateTime.tryParse(_filters[key] ?? '');
                        if (date != null) {
                          _filters[key] = date.toUtc().toIso8601String();
                        }
                      }
                    });
                  },
                  child: const Text('Apply filters'),
                ),
                TextButton(
                  onPressed: () {
                    for (final field in _fields.values) {
                      field.clear();
                    }
                    setState(() {
                      _outcome = '';
                      _filters = {};
                      _page = 1;
                      _revision++;
                    });
                  },
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      RemoteContent<PagedItems>(
        key: ValueKey('$_page-$_revision'),
        load: () => widget.services.account.audit(_page, _filters),
        builder: (result, reload) => Column(
          children: [
            if (result.items.isEmpty) const InlineNotice('No matching events.'),
            for (final event in result.items)
              Card(
                child: ExpansionTile(
                  title: Text('${event['module']} · ${event['action']}'),
                  subtitle: Text(
                    '${event['outcome']} · ${dateLabel(event['occurredOn'])}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Actor: ${event['actorUserId'] ?? 'System / anonymous'}',
                          ),
                          Text(
                            'Resource: ${event['resourceType'] ?? '—'} / ${event['resourceId'] ?? '—'}',
                          ),
                          SelectableText('Trace: ${event['traceId'] ?? '—'}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _page <= 1 ? null : () => setState(() => _page--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  'Page $_page of ${result.totalPages == 0 ? 1 : result.totalPages}',
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: _page >= result.totalPages
                      ? null
                      : () => setState(() => _page++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            TextButton(onPressed: reload, child: const Text('Refresh events')),
          ],
        ),
      ),
    ],
  );
}
