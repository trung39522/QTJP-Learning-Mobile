import 'dart:convert';
import 'dart:math';

import '../../core/network/api_client.dart';

String? validateEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? null
    : 'Email không đúng định dạng.';
String? validatePhone(String value, {bool required = false}) =>
    !required && value.trim().isEmpty ||
        RegExp(r'^(\+84|0)[0-9]{9}$')
            .hasMatch(value.replaceAll(RegExp(r'\s+'), ''))
    ? null
    : 'Số điện thoại không đúng định dạng.';
String? validatePassword(String value) =>
    value.length >= 8 &&
        value.length <= 64 &&
        RegExp('[A-Za-z]').hasMatch(value) &&
        RegExp('[0-9]').hasMatch(value)
    ? null
    : 'Mật khẩu cần 8–64 ký tự, gồm chữ và số.';

class AccountRepository {
  const AccountRepository(this.api);
  final ApiClient api;
  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String phone,
    String password,
    String confirmation,
  ) async => jsonObject(
    await api.request(
      'POST',
      '/api/users/register',
      body: {
        'username': username.trim(),
        'email': email.trim(),
        'phone': phone.replaceAll(RegExp(r'\s+'), ''),
        'password': password,
        'confirmPassword': confirmation,
      },
    ),
  );
  Future<void> forgot(String email) async {
    await api.request(
      'POST',
      '/api/users/forgot-password',
      body: {'email': email.trim()},
    );
  }

  Future<void> reset(
    String tokenOrLink,
    String password,
    String confirmation,
  ) async {
    final value = tokenOrLink.trim();
    final uri = Uri.tryParse(value);
    final token = uri != null && uri.hasScheme
        ? uri.queryParameters['token'] ?? ''
        : value;
    if (token.isEmpty || token.length > 2048) {
      throw const ApiException('Mã đặt lại mật khẩu không hợp lệ.');
    }
    await api.request(
      'POST',
      '/api/users/reset-password',
      body: {
        'token': token,
        'password': password,
        'confirmPassword': confirmation,
      },
    );
  }

  Future<void> password(
    String current,
    String password,
    String confirmation,
  ) async {
    await api.request(
      'PUT',
      '/api/users/me/password',
      authenticated: true,
      body: {
        'currentPassword': current,
        'newPassword': password,
        'confirmPassword': confirmation,
      },
    );
  }

  Future<Map<String, dynamic>> profile() async =>
      jsonObject(await api.get('/api/users/me/profile', authenticated: true));
  Future<Map<String, dynamic>> saveProfile(String email, String phone) async =>
      jsonObject(
        await api.request(
          'PUT',
          '/api/users/me/profile',
          authenticated: true,
          body: {
            'email': email.trim(),
            'phone': phone.replaceAll(RegExp(r'\s+'), ''),
          },
        ),
      );
  Future<List<Map<String, dynamic>>> sessions() async =>
      jsonObjects(await api.get('/api/users/me/sessions', authenticated: true));
  Future<void> revokeOthers() async {
    await api.request(
      'DELETE',
      '/api/users/me/sessions/others',
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> removeAvatar() async => jsonObject(
    await api.request('DELETE', '/api/users/me/avatar', authenticated: true),
  );
  Future<Map<String, dynamic>> avatar(List<int> bytes) async {
    final png =
        bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
    final jpg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if ((!png && !jpg) || bytes.length > 2 * 1024 * 1024) {
      throw const ApiException(
        'Ảnh đại diện cần là JPG/PNG và không vượt quá 2 MB.',
      );
    }
    final boundary = 'qtjp-${Random.secure().nextInt(1 << 32)}';
    final extension = png ? 'png' : 'jpg';
    final body = ApiBinaryBody([
      ...utf8.encode(
        '--$boundary\r\nContent-Disposition: form-data; name="file"; filename="avatar.$extension"\r\nContent-Type: image/${png ? 'png' : 'jpeg'}\r\n\r\n',
      ),
      ...bytes,
      ...utf8.encode('\r\n--$boundary--\r\n'),
    ], 'multipart/form-data; boundary=$boundary');
    return jsonObject(
      await api.request(
        'POST',
        '/api/users/me/avatar',
        authenticated: true,
        body: body,
      ),
    );
  }
}
