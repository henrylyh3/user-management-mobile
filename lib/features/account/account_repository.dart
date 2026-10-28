import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/api_problem.dart';

class UserProfile {
  UserProfile.fromJson(dynamic value) {
    final json = jsonObject(value);
    id = jsonString(json, 'id');
    firstName = jsonString(json, 'firstName');
    lastName = jsonString(json, 'lastName');
    email = jsonString(json, 'email');
    imageUrl = json['imageUrl'] as String?;
  }
  late final String id, firstName, lastName, email;
  late final String? imageUrl;
  String get name => '$firstName $lastName';
}

class PagedItems {
  PagedItems.fromJson(dynamic value) {
    final json = jsonObject(value);
    if (json['items'] is! List ||
        json['page'] is! int ||
        json['totalPages'] is! int) {
      throw const ApiProblem('The server returned an invalid page.');
    }
    items = (json['items'] as List).map(jsonObject).toList();
    page = json['page'] as int;
    totalPages = json['totalPages'] as int;
  }
  late final List<Map<String, dynamic>> items;
  late final int page, totalPages;
}

class AccountRepository {
  AccountRepository(this.api);
  final ApiClient api;

  Future<UserProfile> profile(String id) async => UserProfile.fromJson(
    await api.request('GET', '/api/User/${Uri.encodeComponent(id)}'),
  );

  Future<UserProfile> update(String id, String first, String last) async =>
      UserProfile.fromJson(
        await api.request(
          'PUT',
          '/api/User/${Uri.encodeComponent(id)}',
          data: {'firstName': first.trim(), 'lastName': last.trim()},
        ),
      );

  Future<void> upload(String id, XFile file) async {
    final bytes = await file.readAsBytes();
    // Leave space for the multipart envelope within the API's 2 MiB request cap.
    if (bytes.length > 2 * 1024 * 1024 - 4096) {
      throw const ApiProblem('Choose a JPEG or PNG smaller than 2 MB.');
    }
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
    final png =
        bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == pngSignature[i]).every((v) => v);
    if (!jpeg && !png) {
      throw const ApiProblem(
        'Only JPEG and PNG images are supported. Export HEIC images as JPEG first.',
      );
    }
    await api.request(
      'PUT',
      '/api/User/${Uri.encodeComponent(id)}/profile-picture',
      bodyFactory: () async => FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: jpeg ? 'profile.jpg' : 'profile.png',
          contentType: MediaType('image', jpeg ? 'jpeg' : 'png'),
        ),
      }),
    );
  }

  Future<void> removeImage(String id) async {
    await api.request(
      'DELETE',
      '/api/User/${Uri.encodeComponent(id)}/profile-picture',
    );
  }

  Future<List<Map<String, dynamic>>> sessions() async {
    final data = await api.request('GET', '/api/auth/sessions');
    if (data is! List) {
      throw const ApiProblem('The server returned an invalid session list.');
    }
    return data.map(jsonObject).toList();
  }

  Future<bool> revoke(String id) async =>
      jsonObject(
        await api.request(
          'DELETE',
          '/api/mobile/auth/sessions/${Uri.encodeComponent(id)}',
        ),
      )['revokedCurrentSession'] ==
      true;

  Future<Map<String, dynamic>> export() async =>
      jsonObject(await api.request('GET', '/api/account/export'));
  Future<void> changePassword(String current, String replacement) async {
    await api.request(
      'POST',
      '/api/mobile/account/change-password',
      data: {'currentPassword': current, 'newPassword': replacement},
    );
  }

  Future<void> delete(String password) async {
    await api.request(
      'DELETE',
      '/api/mobile/account',
      data: {'currentPassword': password},
    );
  }

  Future<PagedItems> users(int page) async => PagedItems.fromJson(
    await api.request(
      'GET',
      '/api/User',
      query: {'page': page, 'pageSize': 20},
    ),
  );
  Future<void> adminMutation(String id, String action, String? value) async {
    await api.request(
      action == 'unlock' ? 'POST' : 'PATCH',
      '/api/mobile/admin/users/${Uri.encodeComponent(id)}/$action',
      data: value == null ? null : {action: value},
    );
  }

  Future<PagedItems> audit(int page, Map<String, String> filters) async =>
      PagedItems.fromJson(
        await api.request(
          'GET',
          '/api/audit-events',
          query: {
            'page': page,
            'pageSize': 20,
            ...Map.fromEntries(
              filters.entries.where((e) => e.value.trim().isNotEmpty),
            ),
          },
        ),
      );
}
