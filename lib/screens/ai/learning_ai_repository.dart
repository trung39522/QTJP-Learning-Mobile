import '../../core/network/api_client.dart';

enum LearningAiTool { dictionary, grammar }

class LearningAiRepository {
  const LearningAiRepository(this.api);
  final ApiClient api;
  Future<Map<String, dynamic>> quota() async => jsonObject(
    await api.get('/api/dictionary/ai/quota', authenticated: true),
  );
  Future<Map<String, dynamic>> request(
    LearningAiTool tool,
    String input, {
    bool explain = false,
  }) async {
    final text = input.trim();
    final limit = tool == LearningAiTool.dictionary ? 100 : 1000;
    if (text.isEmpty || text.runes.length > limit) {
      throw ApiException('Nội dung cần từ 1 đến $limit ký tự.');
    }
    final data = jsonObject(
      await api.request(
        'POST',
        tool == LearningAiTool.dictionary
            ? '/api/dictionary/ai'
            : '/api/grammar/analyze',
        authenticated: true,
        timeout: const Duration(seconds: 120),
        body: tool == LearningAiTool.dictionary
            ? {'keyword': text, 'mode': explain ? 'EXPLAIN' : 'LOOKUP'}
            : {'sentence': text, 'translationHint': '', 'context': ''},
      ),
    );
    if (tool == LearningAiTool.dictionary) {
      final entry = jsonObject(data['entry']);
      if (entry['found'] is! bool) {
        throw const ApiException('Kết quả AI chưa đúng định dạng.');
      }
      jsonObjects(entry['examples'] ?? []);
      aiTexts(entry['relatedWords']);
      if (data['quota'] != null) jsonObject(data['quota']);
    } else {
      for (final point in jsonObjects(data['grammarPoints'] ?? [])) {
        final grammar = jsonObject(point['grammar']);
        aiTexts(grammar['structure']);
        aiTexts(grammar['notes']);
        aiTexts(grammar['relatedPatterns']);
        for (final example in jsonObjects(grammar['examples'] ?? [])) {
          jsonObjects(example['segments'] ?? []);
        }
      }
    }
    return data;
  }
}

List<String> aiTexts(Object? value) {
  if (value == null) return [];
  if (value is! List || value.any((text) => text is! String)) {
    throw const ApiException('Nội dung AI chưa đúng định dạng.');
  }
  return value.cast<String>();
}
