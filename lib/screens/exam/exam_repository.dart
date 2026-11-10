import '../../core/network/api_client.dart';

int examId(Object? value) {
  if (value is! int || value <= 0) {
    throw const ApiException('Dữ liệu đề thi thiếu mã định danh hợp lệ.');
  }
  return value;
}

DateTime? examTime(Object? value) {
  if (value == null || value == '') return null;
  final text = value.toString();
  final hasZone = RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(text);
  // Spring returns LocalDateTime in the backend's timezone, not the phone's.
  const offset = String.fromEnvironment(
    'API_TIMEZONE_OFFSET',
    defaultValue: '+07:00',
  );
  final result = DateTime.tryParse(hasZone ? text : '$text$offset');
  if (result == null) {
    throw const ApiException('Thời gian thi từ máy chủ không hợp lệ.');
  }
  return result;
}

class ExamAttempt {
  ExamAttempt.fromJson(this.data) : id = examId(data['attemptId']) {
    if (!['IN_PROGRESS', 'SUBMITTED'].contains(data['status'])) {
      throw const ApiException('Trạng thái lượt thi từ máy chủ không hợp lệ.');
    }
    if (data['currentSection'] != null) {
      final current = jsonObject(data['currentSection']);
      examId(current['sectionId']);
      for (final question in jsonObjects(current['questions'] ?? [])) {
        examId(question['answerKeyId']);
        jsonObjects(question['choices'] ?? []);
      }
    }
    if (!submitted && section == null && breakState == null) {
      throw const ApiException('Lượt thi chưa có phần làm bài hoặc giờ nghỉ.');
    }
    examTime(section?['expiresAt'] ?? breakState?['expiresAt']);
  }
  final Map<String, dynamic> data;
  final int id;
  bool get submitted => data['status'] == 'SUBMITTED';
  Map<String, dynamic>? get section => data['currentSection'] == null
      ? null
      : jsonObject(data['currentSection']);
  Map<String, dynamic>? get breakState =>
      data['breakState'] == null ? null : jsonObject(data['breakState']);
  List<Map<String, dynamic>> get questions =>
      jsonObjects(section?['questions'] ?? []);
  DateTime? get deadline =>
      examTime(section?['expiresAt'] ?? breakState?['expiresAt']);
  String get deadlineKey =>
      '$id:${section?['sectionId'] ?? breakState?['sectionId']}:${section == null}:$deadline';
}

class ExamRepository {
  const ExamRepository(this.api);
  final ApiClient api;
  Future<List<Map<String, dynamic>>> exams(String level) async => jsonObjects(
    await api.get(
      '/api/jlpt/exams',
      query: {'level': level},
      authenticated: true,
    ),
  );
  Future<List<Map<String, dynamic>>> history() async =>
      jsonObjects(await api.get('/api/jlpt/history', authenticated: true));
  Future<Map<String, dynamic>> detail(int id) async => jsonObject(
    await api.get('/api/jlpt/exams/${examId(id)}', authenticated: true),
  );
  Future<ExamAttempt> start(int id) async => ExamAttempt.fromJson(
    jsonObject(
      await api.request(
        'POST',
        '/api/jlpt/attempts/start',
        authenticated: true,
        body: {'examId': examId(id)},
      ),
    ),
  );
  Future<ExamAttempt> attempt(int id) async => ExamAttempt.fromJson(
    jsonObject(
      await api.get('/api/jlpt/attempts/${examId(id)}', authenticated: true),
    ),
  );
  Future<Map<String, dynamic>> answer(
    int attempt,
    int key,
    int? option,
  ) async => jsonObject(
    await api.request(
      'PUT',
      '/api/jlpt/attempts/${examId(attempt)}/answer',
      authenticated: true,
      body: {'answerKeyId': examId(key), 'selectedOption': option},
    ),
  );
  Future<Map<String, dynamic>> mark(int attempt, int key, bool marked) async =>
      jsonObject(
        await api.request(
          'PUT',
          '/api/jlpt/attempts/${examId(attempt)}/mark',
          authenticated: true,
          body: {'answerKeyId': examId(key), 'markedForReview': marked},
        ),
      );
  Future<ExamAttempt> complete(int id) async => ExamAttempt.fromJson(
    jsonObject(
      await api.request(
        'POST',
        '/api/jlpt/attempts/${examId(id)}/complete-section',
        authenticated: true,
      ),
    ),
  );
  Future<ExamAttempt> next(int id) async => ExamAttempt.fromJson(
    jsonObject(
      await api.request(
        'POST',
        '/api/jlpt/attempts/${examId(id)}/start-next-section',
        authenticated: true,
      ),
    ),
  );
  Future<Map<String, dynamic>> result(int id) async => jsonObject(
    await api.get(
      '/api/jlpt/attempts/${examId(id)}/result',
      authenticated: true,
    ),
  );

  Uri asset(String path, {String? relativeTo}) {
    final base = Uri.parse(api.baseUrl);
    final uri = (relativeTo == null ? base : base.resolve(relativeTo)).resolve(
      path.replaceAll('\\', '/'),
    );
    if (!['http', 'https'].contains(uri.scheme) ||
        uri.origin != base.origin ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const ApiException(
        'Địa chỉ tài liệu đề thi không thuộc máy chủ QTJP.',
      );
    }
    return uri;
  }

  Future<Map<String, dynamic>> document(String path) async {
    final uri = asset(path);
    // Static documents have no bearer token, matching the website contract.
    return jsonObject(await api.get(uri.path, query: uri.queryParameters));
  }
}
