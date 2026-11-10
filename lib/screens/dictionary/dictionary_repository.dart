import '../../core/network/api_client.dart';

class DictionaryRepository {
  const DictionaryRepository(this.api);
  final ApiClient api;

  Future<List<DictionaryEntry>> search(String keyword) async {
    if (keyword.trim().isEmpty) return const [];
    final rows = jsonObjects(
      await api.get(
        '/api/dictionary/search',
        query: {'keyword': keyword.trim()},
      ),
    );
    return rows.map(DictionaryEntry.fromJson).toList(growable: false);
  }
}

class DictionaryEntry {
  DictionaryEntry.fromJson(Map<String, dynamic> row)
    : word = jsonText(row, 'word').isEmpty
          ? jsonText(row, 'kanji')
          : jsonText(row, 'word'),
      reading = jsonText(row, 'hiragana'),
      romaji = jsonText(row, 'romaji'),
      meaning = jsonText(row, 'meaning'),
      level = jsonText(row, 'level'),
      hanViet = jsonText(row, 'hanViet'),
      partOfSpeech = jsonText(row, 'partOfSpeech'),
      examples = row['examples'] == null
          ? const []
          : jsonObjects(row['examples']),
      relations = row['relations'] == null
          ? const []
          : jsonObjects(row['relations']);

  final String word, reading, romaji, meaning, level, hanViet, partOfSpeech;
  final List<Map<String, dynamic>> examples, relations;
}
