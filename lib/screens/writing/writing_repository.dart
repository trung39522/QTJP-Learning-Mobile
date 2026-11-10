import '../../core/network/api_client.dart';

List<String> _strings(Object? value) {
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! String)) {
    throw const ApiException(
      'Nội dung luyện viết từ máy chủ chưa đúng định dạng.',
    );
  }
  return List<String>.unmodifiable(value.cast<String>());
}

int _id(Object? value) {
  if (value is! num || value <= 0) {
    throw const ApiException('Dữ liệu luyện viết thiếu mã định danh.');
  }
  return value.toInt();
}

class WritingTopic {
  WritingTopic.fromJson(Map<String, dynamic> data)
    : id = _id(data['id']),
      title = jsonText(data, 'title'),
      level = jsonText(data, 'level'),
      category = jsonText(data, 'category'),
      minSentences = (data['minSentences'] as num?)?.toInt(),
      maxSentences = (data['maxSentences'] as num?)?.toInt(),
      vocabularyHints = _strings(data['vocabularyHints']),
      grammarHints = _strings(data['grammarHints']);

  final int id;
  final String title, level, category;
  final int? minSentences, maxSentences;
  final List<String> vocabularyHints, grammarHints;
}

class WritingReview {
  WritingReview.fromJson(Map<String, dynamic> data)
    : id = _id(data['writingId']),
      attempt = (data['attemptNumber'] as num?)?.toInt() ?? 1,
      previousScore = (data['previousScore'] as num?)?.toInt(),
      improvement = (data['improvement'] as num?)?.toInt(),
      model = jsonText(data, 'aiModel'),
      evaluation = jsonObject(data['evaluation']) {
    if (evaluation['totalScore'] is! num) {
      throw const ApiException('Máy chủ chưa trả điểm chấm bài hợp lệ.');
    }
    scores = evaluation['scores'] == null
        ? const {}
        : jsonObject(evaluation['scores']);
    corrections = jsonObjects(evaluation['corrections'] ?? []);
    suggestions = jsonObjects(evaluation['vocabularySuggestions'] ?? []);
    strengths = _strings(evaluation['strengths']);
    nextSteps = _strings(evaluation['nextSteps']);
  }

  final int id, attempt;
  final int? previousScore, improvement;
  final String model;
  final Map<String, dynamic> evaluation;
  late final Map<String, dynamic> scores;
  late final List<Map<String, dynamic>> corrections, suggestions;
  late final List<String> strengths, nextSteps;
  int get score => (evaluation['totalScore'] as num).toInt();
  String get summary => jsonText(evaluation, 'summary');
  String get correctedText => jsonText(evaluation, 'correctedText');
}

class WritingAttempt {
  WritingAttempt.fromJson(Map<String, dynamic> data)
    : id = _id(data['id']),
      text = jsonText(data, 'text'),
      score = (data['score'] as num?)?.toInt(),
      number = (data['attemptNumber'] as num?)?.toInt() ?? 1,
      date = jsonText(data, 'submittedAt');
  final int id, number;
  final int? score;
  final String text, date;
}

class WritingHistoryGroup {
  WritingHistoryGroup.fromJson(Map<String, dynamic> data)
    : topic = WritingTopic.fromJson({
        'id': data['topicId'],
        'title': data['topicTitle'],
        'level': data['level'],
      }),
      firstScore = (data['firstScore'] as num?)?.toInt(),
      latestScore = (data['latestScore'] as num?)?.toInt(),
      improvement = (data['improvement'] as num?)?.toInt(),
      attempts = jsonObjects(data['attempts'] ?? [])
          .map(WritingAttempt.fromJson)
          .toList(growable: false);
  final WritingTopic topic;
  final int? firstScore, latestScore, improvement;
  final List<WritingAttempt> attempts;
}

class WritingHistory {
  const WritingHistory(this.groups, this.stats);
  final List<WritingHistoryGroup> groups;
  final Map<String, dynamic> stats;
}

class WritingRepository {
  const WritingRepository(this.api);
  final ApiClient api;

  Future<List<WritingTopic>> topics(String level) async => jsonObjects(
    await api.get(
      '/api/writing/topics',
      query: {'level': level},
      authenticated: true,
    ),
  ).map(WritingTopic.fromJson).toList(growable: false);

  Future<WritingTopic> generate(String level, String category) async =>
      WritingTopic.fromJson(
        jsonObject(
          await api.request(
            'POST',
            '/api/writing/topics/generate',
            authenticated: true,
            timeout: const Duration(seconds: 120),
            body: {'level': level, 'category': category},
          ),
        ),
      );

  Future<WritingReview> submit(
    int topicId,
    String text, {
    int? parentWritingId,
  }) async {
    if (text.trim().isEmpty || text.trim().length > 10000) {
      throw const ApiException('Bài viết cần có từ 1 đến 10.000 ký tự.');
    }
    return WritingReview.fromJson(
      jsonObject(
        await api.request(
          'POST',
          '/api/writing/submit',
          authenticated: true,
          timeout: const Duration(seconds: 180),
          body: {
            'topicId': topicId,
            'text': text.trim(),
            'parentWritingId': parentWritingId,
          },
        ),
      ),
    );
  }

  Future<WritingHistory> history() async {
    final responses = await Future.wait([
      api.get('/api/writing/history', authenticated: true),
      api.get('/api/writing/stats', authenticated: true),
    ]);
    return WritingHistory(
      jsonObjects(responses[0])
          .map(WritingHistoryGroup.fromJson)
          .toList(growable: false),
      jsonObject(responses[1]),
    );
  }
}
