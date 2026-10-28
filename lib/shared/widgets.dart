import 'package:flutter/material.dart';

import '../core/api_problem.dart';
import '../app/coral_theme.dart';

String safeError(Object error) => error is ApiProblem
    ? error.message
    : 'Something went wrong. Please try again.';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class ContentPage extends StatelessWidget {
  const ContentPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
  });
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width < 600 ? 20 : 40,
              24,
              MediaQuery.sizeOf(context).width < 600 ? 20 : 40,
              48,
            ),
            children: [
              Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 28),
                color: Coral.rule,
              ),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

class InlineNotice extends StatelessWidget {
  const InlineNotice(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Coral.cotton,
          border: Border(
            left: BorderSide(
              color: error ? Coral.error : Coral.accent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          message,
          style: TextStyle(color: error ? Coral.error : Coral.ink),
        ),
      ),
    ),
  );
}

class RemoteContent<T> extends StatefulWidget {
  const RemoteContent({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(T, VoidCallback) builder;
  @override
  State<RemoteContent<T>> createState() => _RemoteContentState<T>();
}

class _RemoteContentState<T> extends State<RemoteContent<T>> {
  late Future<T> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void reload() => setState(() => _future = widget.load());
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (snapshot.hasError) {
        return Column(
          children: [
            InlineNotice(safeError(snapshot.error!), error: true),
            OutlinedButton(onPressed: reload, child: const Text('Try again')),
          ],
        );
      }
      return widget.builder(snapshot.data as T, reload);
    },
  );
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

String dateLabel(dynamic value) {
  final date = value is String ? DateTime.tryParse(value)?.toLocal() : null;
  return date == null ? '—' : date.toString().split('.').first;
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;
String? passwordText(String? value) =>
    value == null || value.length < 8 || value.length > 128
    ? 'Use 8–128 characters.'
    : null;
String? nameText(String? value) =>
    requiredText(value) ??
    (value!.trim().length > 100 ? 'Use at most 100 characters.' : null);
String? emailText(String? value) =>
    value == null ||
        value.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? 'Enter a valid email address.'
    : null;
