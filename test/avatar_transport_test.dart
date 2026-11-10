import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/screens/auth/account_repository.dart';

// Separate from widget tests: their binding deliberately intercepts HttpClient.
void main() {
  test(
    'avatar uses binary multipart and rejects unsupported/oversized files',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        expect(request.headers.value('Authorization'), 'Bearer test');
        expect(request.headers.contentType?.mimeType, 'multipart/form-data');
        final bytes = await request.fold<List<int>>(
          [],
          (all, chunk) => all..addAll(chunk),
        );
        final text = latin1.decode(bytes);
        expect(text, contains('name="file"; filename="avatar.jpg"'));
        expect(text, contains('Content-Type: image/jpeg'));
        expect(bytes, containsAllInOrder([255, 216, 255]));
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"id":1}');
        await request.response.close();
      });
      final repo = AccountRepository(
        ApiClient(baseUrl: 'http://127.0.0.1:${server.port}')..token = 'test',
      );
      await repo.avatar([255, 216, 255, 0]);
      await expectLater(repo.avatar([1, 2, 3]), throwsA(isA<ApiException>()));
      await expectLater(
        repo.avatar([255, 216, 255, ...List.filled(2 * 1024 * 1024, 0)]),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
