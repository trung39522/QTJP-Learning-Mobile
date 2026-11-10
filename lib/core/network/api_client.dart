import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.code, this.details});
  final String message;
  final int? status;
  final String? code;
  final Map<String, dynamic>? details;
  bool get requiresLogin => status == 401;
  @override
  String toString() => message;
}

class ApiResponse {
  const ApiResponse(this.status, this.data);
  final int status;
  final Object? data;
}

typedef ApiTransport = Future<ApiResponse> Function(
  String method,
  Uri uri,
  Map<String, String> headers,
  Object? body,
);

class ApiBinaryBody {
  const ApiBinaryBody(this.bytes, this.contentType);
  final List<int> bytes;
  final String contentType;
}

/// Native Android/iOS HTTP, using the same JSON contracts as the website.
/// No passwords/tokens are logged or persisted in plain text.
class ApiClient {
  ApiClient({String? baseUrl, this._transport})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: kReleaseMode ? '' : 'http://127.0.0.1:8080',
          );

  final String baseUrl;
  final ApiTransport? _transport;
  String? _token;
  int _sessionVersion = 0;
  String? get token => _token;
  int get sessionVersion => _sessionVersion;
  set token(String? value) {
    _token = value;
    _sessionVersion++;
  }

  VoidCallback? onUnauthorized;

  Future<Object?> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = false,
    Duration timeout = const Duration(seconds: 15),
  }) => request(
    'GET',
    path,
    query: query,
    authenticated: authenticated,
    timeout: timeout,
  );

  Future<Object?> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = false,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final requestToken = token;
    final requestSession = sessionVersion;
    if (authenticated && requestToken == null) {
      throw const ApiException(
        'Đăng nhập bằng tài khoản QTJP để tải dữ liệu học của website.',
        status: 401,
      );
    }
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        !base.hasAuthority ||
        !['https', 'http'].contains(base.scheme) ||
        base.userInfo.isNotEmpty) {
      throw const ApiException(
        'Chưa cấu hình máy chủ API. Cần API_BASE_URL trỏ đến backend QTJP.',
      );
    }
    if (kReleaseMode && base.scheme != 'https') {
      throw const ApiException(
        'Bản phát hành yêu cầu địa chỉ API HTTPS để bảo vệ tài khoản.',
      );
    }
    final uri = base.resolve(path).replace(queryParameters: query);
    if (uri.origin != base.origin || uri.userInfo.isNotEmpty) {
      throw const ApiException(
        'Địa chỉ API không thuộc máy chủ QTJP đã cấu hình.',
      );
    }
    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': body is ApiBinaryBody
            ? body.contentType
            : 'application/json; charset=utf-8',
        'User-Agent': 'QTJP-Mobile/1.0',
        if (authenticated) 'Authorization': 'Bearer $requestToken',
      };
      final response =
          await (_transport != null
                  ? _transport(method, uri, headers, body)
                  : _nativeRequest(method, uri, headers, body, timeout))
              .timeout(timeout);
      if (authenticated && requestSession != sessionVersion) {
        throw const ApiException(
          'Phiên học đã thay đổi. Vui lòng mở lại nội dung bằng tài khoản hiện tại.',
          status: 401,
          code: 'SESSION_CHANGED',
        );
      }
      if (response.status < 200 || response.status >= 300) {
        final payload = response.data is Map ? response.data as Map : const {};
        if (response.status == 401 && authenticated && token == requestToken) {
          onUnauthorized?.call();
        }
        final message = payload['message'] ?? payload['error'];
        throw ApiException(
          message is String && message.isNotEmpty
              ? message
              : switch (response.status) {
                  401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
                  403 => 'Tài khoản chưa có quyền truy cập nội dung này.',
                  _ => 'Máy chủ trả lỗi ${response.status}. Vui lòng thử lại.',
                },
          status: response.status,
          code: payload['code']?.toString(),
          details: payload is Map<String, dynamic> ? payload : null,
        );
      }
      return response.data;
    } on TimeoutException {
      throw ApiException(
        method == 'GET'
            ? 'Máy chủ phản hồi quá lâu. Kiểm tra kết nối rồi thử lại.'
            : 'Chưa nhận được kết quả; máy chủ có thể vẫn đang xử lý. Hãy kiểm tra lịch sử trước khi gửi lại để tránh trùng yêu cầu.',
        code: 'REQUEST_TIMEOUT',
      );
    } on SocketException {
      throw const ApiException(
        'Không kết nối được backend QTJP. Nếu đang chạy qua USB, hãy giữ backend và kết nối USB hoạt động.',
      );
    } on HandshakeException {
      throw const ApiException('Không thể xác minh kết nối HTTPS của máy chủ.');
    } on HttpException {
      throw const ApiException(
        'Kết nối đến máy chủ bị gián đoạn. Vui lòng thử lại.',
      );
    } on FormatException {
      throw const ApiException('Dữ liệu máy chủ không đúng định dạng JSON.');
    }
  }

  static Future<ApiResponse> _nativeRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
    Duration timeout,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      return await (() async {
        final request = await client.openUrl(method, uri);
        // Never forward a bearer token/password to a different redirect target.
        request.followRedirects = false;
        headers.forEach(request.headers.set);
        if (body is ApiBinaryBody) {
          request.add(body.bytes);
        } else if (body != null) {
          request.add(utf8.encode(jsonEncode(body)));
        }
        final response = await request.close();
        final content = await response.transform(utf8.decoder).join();
        Object? data;
        if (content.trim().isNotEmpty) {
          try {
            data = jsonDecode(content);
          } on FormatException {
            // Gateways may return HTML for errors. Preserve HTTP auth/status
            // handling even when that response does not contain JSON.
            if (response.statusCode >= 200 && response.statusCode < 300) {
              rethrow;
            }
          }
        }
        return ApiResponse(response.statusCode, data);
      })().timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }
}

List<Map<String, dynamic>> jsonObjects(Object? value) {
  if (value is! List || value.any((item) => item is! Map<String, dynamic>)) {
    throw const ApiException('Cấu trúc dữ liệu máy chủ không hợp lệ.');
  }
  return value.cast<Map<String, dynamic>>();
}

Map<String, dynamic> jsonObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const ApiException('Cấu trúc dữ liệu máy chủ không hợp lệ.');
  }
  return value;
}

String jsonText(Map<String, dynamic> value, String key) =>
    value[key]?.toString() ?? '';
