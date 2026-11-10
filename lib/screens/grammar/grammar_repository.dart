import '../../core/network/api_client.dart';

class GrammarRepository {
  const GrammarRepository(this.api);
  final ApiClient api;
  Future<List<Map<String, dynamic>>> lessons(String level) async => jsonObjects(
    await api.get(
      '/api/grammar/lessons',
      query: {'level': level},
      authenticated: true,
    ),
  );
  Future<Map<String, dynamic>> lesson(String id) async => jsonObject(
    await api.get(
      '/api/grammar/lessons/${Uri.encodeComponent(id)}',
      authenticated: true,
    ),
  );
}
