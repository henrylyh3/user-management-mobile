import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../shared/widgets.dart';

class CaptchaPage extends StatefulWidget {
  const CaptchaPage({super.key, required this.pageUrl, required this.action});
  final String pageUrl, action;
  @override
  State<CaptchaPage> createState() => _CaptchaPageState();
}

class _CaptchaPageState extends State<CaptchaPage> {
  WebViewController? _controller;
  String? _error;
  bool _complete = false;
  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.pageUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty) {
      _error =
          'Human verification is not configured. Contact the administrator.';
      return;
    }
    final challenge = uri.replace(
      queryParameters: {...uri.queryParameters, 'action': widget.action},
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'Captcha',
        onMessageReceived: (message) async {
          if (_complete ||
              message.message.isEmpty ||
              message.message.length > 2048) {
            return;
          }
          final current = Uri.tryParse(await _controller!.currentUrl() ?? '');
          if (current?.origin != challenge.origin ||
              current?.path != challenge.path) {
            return;
          }
          if (mounted) {
            _complete = true;
            Navigator.pop(context, message.message);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final target = Uri.tryParse(request.url);
            if (target == null || target.scheme != 'https') {
              return NavigationDecision.prevent;
            }
            if (!request.isMainFrame &&
                target.host == 'challenges.cloudflare.com') {
              return NavigationDecision.navigate;
            }
            return target.origin == challenge.origin &&
                    target.path == challenge.path
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(
                () => _error =
                    'Unable to load verification. Close this page and try again.',
              );
            }
          },
        ),
      )
      ..loadRequest(challenge);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Human verification')),
    body: _error != null
        ? Padding(
            padding: const EdgeInsets.all(24),
            child: InlineNotice(_error!, error: true),
          )
        : WebViewWidget(controller: _controller!),
  );
}
