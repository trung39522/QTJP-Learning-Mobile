import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qtjp_mobile/app/app_controller.dart';
import 'package:qtjp_mobile/core/network/api_client.dart';
import 'package:qtjp_mobile/screens/dictionary/dictionary_repository.dart';
import 'package:qtjp_mobile/screens/flashcard/data/flashcard_repository.dart';
import 'package:qtjp_mobile/screens/grammar/grammar_repository.dart';

void main() {
  test(
    'non-JSON HTTP errors preserve session expiry and access denial',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var status = 401;
      server.listen((request) async {
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType.html;
        request.response.write('<html>Gateway error</html>');
        await request.response.close();
      });
      var expirations = 0;
      final api = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}')
        ..token = 'test-token'
        ..onUnauthorized = () => expirations++;
      await expectLater(
        api.get('/protected', authenticated: true),
        throwsA(
          isA<ApiException>().having((e) => e.status, 'HTTP status', 401),
        ),
      );
      expect(expirations, 1);
      status = 403;
      await expectLater(
        api.get('/protected', authenticated: true),
        throwsA(
          isA<ApiException>().having((e) => e.status, 'HTTP status', 403),
        ),
      );
      expect(expirations, 1);
      status = 200;
      await expectLater(
        api.get('/malformed'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'invalid success payload',
            contains('JSON'),
          ),
        ),
      );
    },
  );

  test(
    'native HTTP transport decodes UTF-8 Japanese/Vietnamese JSON',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        expect(request.uri.queryParameters['keyword'], '学校');
        expect(request.headers.value('Authorization'), isNull);
        request.response.headers.contentType = ContentType.json;
        request.response.add(
          utf8.encode(
            jsonEncode([
              {'word': '学校', 'hiragana': 'がっこう', 'meaning': 'trường học'},
            ]),
          ),
        );
        await request.response.close();
      });
      final words = await DictionaryRepository(
        ApiClient(baseUrl: 'http://127.0.0.1:${server.port}'),
      ).search('学校');
      expect(words.single.word, '学校');
      expect(words.single.meaning, 'trường học');
    },
  );

  test(
    'login uses website contract and protected requests use bearer token',
    () async {
      final requests = <Map<String, Object?>>[];
      final app = AppController(
        api: ApiClient(
          transport: (method, uri, headers, body) async {
            requests.add({
              'method': method,
              'uri': uri,
              'headers': headers,
              'body': body,
            });
            if (uri.path == '/api/users/login') {
              return const ApiResponse(200, {
                'id': 9,
                'username': 'learner',
                'token': 'test-token',
              });
            }
            return const ApiResponse(200, []);
          },
        ),
      );
      addTearDown(app.dispose);
      await app.login(' learner ', ' password ');
      expect(requests.first['body'], {
        'username': 'learner',
        'password': ' password ',
        'replaceOtherSession': false,
      });
      expect(app.isAuthenticated, isTrue);
      expect(app.user!.containsKey('token'), isFalse);
      await app.api.get('/api/grammar/lessons', authenticated: true);
      expect(
        (requests.last['headers'] as Map)['Authorization'],
        'Bearer test-token',
      );
      await app.api.get('/api/dictionary/search');
      expect(
        (requests.last['headers'] as Map).containsKey('Authorization'),
        isFalse,
      );
      await app.logout();
      expect(app.isAuthenticated, isFalse);
      expect(app.api.token, isNull);
    },
  );

  test(
    'guest requests never call protected APIs or return sample data',
    () async {
      var calls = 0;
      final api = ApiClient(
        transport: (m, u, h, b) async {
          calls++;
          return const ApiResponse(200, []);
        },
      );
      await expectLater(
        ApiFlashcardRepository(api).getDecks('N3'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.requiresLogin,
            'requires login',
            true,
          ),
        ),
      );
      expect(calls, 0);
    },
  );

  test(
    'expired sessions are cleared, while forbidden content does not log out',
    () async {
      var status = 200;
      final app = AppController(
        api: ApiClient(
          transport: (m, u, h, b) async => ApiResponse(
            status,
            status == 200
                ? {'id': 1, 'username': 'learner', 'token': 'old'}
                : {'message': 'Unauthorized'},
          ),
        ),
      );
      addTearDown(app.dispose);
      await app.login('learner', 'password');
      status = 403;
      await expectLater(
        app.api.get('/protected', authenticated: true),
        throwsA(isA<ApiException>()),
      );
      expect(app.isAuthenticated, isTrue);
      status = 401;
      await expectLater(
        app.api.get('/protected', authenticated: true),
        throwsA(isA<ApiException>()),
      );
      expect(app.isAuthenticated, isFalse);
    },
  );

  test(
    'VIP conflict is exposed without silently replacing another session',
    () async {
      final app = AppController(
        api: ApiClient(
          transport: (m, u, h, body) async {
            expect((body as Map)['replaceOtherSession'], isFalse);
            return const ApiResponse(409, {
              'code': 'VIP_SESSION_ACTIVE',
              'message': 'Phiên khác đang hoạt động',
            });
          },
        ),
      );
      addTearDown(app.dispose);
      await expectLater(
        app.login('vip', 'password'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'conflict code',
            'VIP_SESSION_ACTIVE',
          ),
        ),
      );
      expect(app.isAuthenticated, isFalse);
    },
  );

  test(
    'flashcard loads metadata then vocabulary and posts exact progress IDs',
    () async {
      final api = ApiClient(
        transport: (method, uri, headers, body) async {
          if (uri.path.endsWith('/decks')) {
            expect(uri.queryParameters['level'], 'N3');
            return const ApiResponse(200, [
              {'id': 42, 'name': 'Công việc', 'level': 'N3', 'wordCount': 1},
            ]);
          }
          if (uri.path.endsWith('/vocabularies')) {
            return const ApiResponse(200, [
              {
                'id': 100,
                'word': '仕事',
                'hiragana': 'しごと',
                'meaning': 'công việc',
                'exampleJapanese': '仕事をします。',
                'exampleVietnamese': 'Tôi làm việc.',
              },
            ]);
          }
          expect(method, 'POST');
          expect(body, {'vocabularyId': 100, 'remembered': true});
          return const ApiResponse(200, {});
        },
      )..token = 'test-token';
      final repo = ApiFlashcardRepository(api);
      final decks = await repo.getDecks('N3');
      expect(decks.single.count, 1);
      expect(decks.single.words, isEmpty);
      expect(decks.single.isSample, isFalse);
      final words = await repo.getWords(decks.single);
      expect(words.single.word, '仕事');
      expect(words.single.exampleVi, 'Tôi làm việc.');
      await repo.saveProgress(words.single, true);
    },
  );

  test('dictionary retains Japanese, Vietnamese, null optional fields and examples', () async {
    final api = ApiClient(
      transport: (m, uri, h, b) async {
        expect(uri.queryParameters['keyword'], '学校');
        return const ApiResponse(200, [
          {
            'word': '学校',
            'hiragana': 'がっこう',
            'romaji': null,
            'meaning': 'trường học',
            'examples': [
              {'japanese': '学校に行きます。', 'vietnamese': 'Tôi đi học.'},
            ],
          },
        ]);
      },
    );
    final words = await DictionaryRepository(api).search(' 学校 ');
    expect(words.single.word, '学校');
    expect(words.single.meaning, 'trường học');
    expect(words.single.romaji, '');
    expect(words.single.examples.single['japanese'], '学校に行きます。');
  });

  test(
    'grammar uses website list and detail endpoints without relabeling level',
    () async {
      final api = ApiClient(
        transport: (m, uri, h, b) async {
          if (uri.path.endsWith('/lessons')) {
            expect(uri.queryParameters['level'], 'N2');
            return const ApiResponse(200, [
              {'id': 7, 'level': 'N2', 'title': 'Bài 1'},
            ]);
          }
          expect(uri.path, '/api/grammar/lessons/7');
          return const ApiResponse(200, {'id': 7, 'grammarPoints': []});
        },
      )..token = 'test-token';
      final repo = GrammarRepository(api);
      expect((await repo.lessons('N2')).single['level'], 'N2');
      expect((await repo.lesson('7'))['grammarPoints'], isEmpty);
    },
  );

  test(
    'invalid API payload is reported instead of pretending there is no data',
    () async {
      final api = ApiClient(
        transport: (m, u, h, b) async =>
            const ApiResponse(200, {'unexpected': true}),
      );
      await expectLater(
        DictionaryRepository(api).search('猫'),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
