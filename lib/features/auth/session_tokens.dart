import '../../core/api_problem.dart';

class SessionTokens {
  SessionTokens.fromJson(dynamic value) {
    final json = jsonObject(value);
    accessToken = jsonString(json, 'accessToken');
    refreshToken = jsonString(json, 'refreshToken');
    sessionId = jsonString(json, 'sessionId');
    accessTokenExpiresAt = DateTime.parse(
      jsonString(json, 'accessTokenExpiresAt'),
    ).toUtc();
    refreshTokenExpiresAt = DateTime.parse(
      jsonString(json, 'refreshTokenExpiresAt'),
    ).toUtc();
    if (!accessTokenExpiresAt.isAfter(DateTime.now().toUtc()) ||
        !refreshTokenExpiresAt.isAfter(DateTime.now().toUtc())) {
      throw const ApiProblem('The server returned an expired session.');
    }
  }
  late final String accessToken;
  late final String refreshToken;
  late final String sessionId;
  late final DateTime accessTokenExpiresAt;
  late final DateTime refreshTokenExpiresAt;
}

class CurrentUser {
  CurrentUser.fromJson(dynamic value) {
    final json = jsonObject(value);
    id = jsonString(json, 'userId');
    email = jsonString(json, 'email');
    role = jsonString(json, 'role');
    if (json['isAuthenticated'] != true || !['User', 'Admin'].contains(role)) {
      throw const ApiProblem('The server returned an invalid user session.');
    }
  }
  late final String id;
  late final String email;
  late final String role;
  bool get isAdmin => role == 'Admin';
}
