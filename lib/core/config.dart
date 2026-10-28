import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({required this.apiUrl, this.challengeUrl = ''});

  factory AppConfig.environment() => const AppConfig(
    apiUrl: String.fromEnvironment('API_BASE_URL'),
    challengeUrl: String.fromEnvironment('CAPTCHA_PAGE_URL'),
  );

  final String apiUrl;
  final String challengeUrl;

  String? get error {
    final uri = Uri.tryParse(apiUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return 'Set API_BASE_URL to the ASP.NET API origin using --dart-define.';
    }
    if (uri.scheme != 'https' && (kReleaseMode || uri.scheme != 'http')) {
      return 'The API must use HTTPS in release builds.';
    }
    return null;
  }

  Uri? imageUri(String? value) {
    if (value == null || value.isEmpty) return null;
    final reference = Uri.tryParse(value);
    if (reference == null) return null;
    final uri = Uri.parse(apiUrl).resolveUri(reference);
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
    return uri.scheme == 'https' || (!kReleaseMode && uri.scheme == 'http')
        ? uri
        : null;
  }
}
