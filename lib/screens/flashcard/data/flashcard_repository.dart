import '../models/flashcard_deck.dart';
import '../../../core/network/api_client.dart';

abstract interface class FlashcardRepository {
  Future<List<FlashcardDeck>> getDecks(String level);
  Future<List<FlashcardWord>> getWords(FlashcardDeck deck);
  Future<void> saveProgress(FlashcardWord word, bool remembered);
}

class ApiFlashcardRepository implements FlashcardRepository {
  ApiFlashcardRepository(this.api);
  final ApiClient api;

  @override
  Future<List<FlashcardDeck>> getDecks(String level) async {
    final rows = jsonObjects(
      await api.get(
        '/api/flashcards/decks',
        query: {'level': level},
        authenticated: true,
      ),
    );
    return rows
        .map(
          (row) => FlashcardDeck(
            id: jsonText(row, 'id'),
            name: jsonText(row, 'name'),
            level: jsonText(row, 'level'),
            description: jsonText(row, 'description'),
            wordCount: (row['wordCount'] as num?)?.toInt() ?? 0,
            words: const [],
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<FlashcardWord>> getWords(FlashcardDeck deck) async {
    final rows = jsonObjects(
      await api.get(
        '/api/flashcards/decks/${Uri.encodeComponent(deck.id)}/vocabularies',
        authenticated: true,
      ),
    );
    return rows
        .map(
          (row) => FlashcardWord(
            id: (row['id'] as num?)?.toInt(),
            word: jsonText(row, 'word').isNotEmpty
                ? jsonText(row, 'word')
                : jsonText(row, 'kanji'),
            hiragana: jsonText(row, 'hiragana'),
            romaji: jsonText(row, 'romaji'),
            meaning: jsonText(row, 'meaning'),
            example: jsonText(row, 'exampleJapanese'),
            exampleVi: jsonText(row, 'exampleVietnamese'),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveProgress(FlashcardWord word, bool remembered) async {
    if (word.id == null) {
      throw const ApiException(
        'Từ vựng thiếu mã định danh, chưa thể lưu tiến độ.',
      );
    }
    await api.request(
      'POST',
      '/api/flashcards/progress',
      authenticated: true,
      body: {'vocabularyId': word.id, 'remembered': remembered},
    );
  }
}

/// Small, explicitly labelled sample sets; not a copy of the server catalogue.
class DemoFlashcardRepository implements FlashcardRepository {
  const DemoFlashcardRepository();

  @override
  Future<List<FlashcardDeck>> getDecks(String level) async =>
      List.unmodifiable(_demoDecks.where((deck) => deck.level == level));

  @override
  Future<List<FlashcardWord>> getWords(FlashcardDeck deck) async => deck.words;

  @override
  Future<void> saveProgress(FlashcardWord word, bool remembered) async {}
}

final _demoDecks = <FlashcardDeck>[
  FlashcardDeck(
    id: 'demo-n5-learning',
    isSample: true,
    name: 'Con người & học tập',
    level: 'N5',
    description:
        'Những từ quen thuộc khi giới thiệu bản thân và nói về việc học.',
    words: const [
      FlashcardWord(
        word: '私',
        hiragana: 'わたし',
        romaji: 'watashi',
        meaning: 'tôi',
        example: '私は学生です。',
        exampleVi: 'Tôi là học sinh / sinh viên.',
      ),
      FlashcardWord(
        word: '学生',
        hiragana: 'がくせい',
        romaji: 'gakusei',
        meaning: 'học sinh / sinh viên',
        example: '田中さんは学生です。',
        exampleVi: 'Bạn Tanaka là học sinh / sinh viên.',
      ),
      FlashcardWord(
        word: '先生',
        hiragana: 'せんせい',
        romaji: 'sensei',
        meaning: 'giáo viên / thầy cô',
        example: '先生に聞きます。',
        exampleVi: 'Tôi hỏi thầy / cô.',
      ),
      FlashcardWord(
        word: '友達',
        hiragana: 'ともだち',
        romaji: 'tomodachi',
        meaning: 'bạn bè',
        example: '友達と勉強します。',
        exampleVi: 'Tôi học cùng bạn.',
      ),
      FlashcardWord(
        word: '日本語',
        hiragana: 'にほんご',
        romaji: 'nihongo',
        meaning: 'tiếng Nhật',
        example: '日本語を勉強します。',
        exampleVi: 'Tôi học tiếng Nhật.',
      ),
    ],
  ),
  FlashcardDeck(
    id: 'demo-n5-daily',
    isSample: true,
    name: 'Cuộc sống hằng ngày',
    level: 'N5',
    description: 'Bắt đầu với đồ vật, con vật và hoạt động quanh bạn.',
    words: const [
      FlashcardWord(
        word: '食べる',
        hiragana: 'たべる',
        romaji: 'taberu',
        meaning: 'ăn',
        example: 'パンを食べます。',
        exampleVi: 'Tôi ăn bánh mì.',
      ),
      FlashcardWord(
        word: '飲む',
        hiragana: 'のむ',
        romaji: 'nomu',
        meaning: 'uống',
        example: '水を飲みます。',
        exampleVi: 'Tôi uống nước.',
      ),
      FlashcardWord(
        word: '水',
        hiragana: 'みず',
        romaji: 'mizu',
        meaning: 'nước',
        example: '水をください。',
        exampleVi: 'Cho tôi xin nước.',
      ),
      FlashcardWord(
        word: '本',
        hiragana: 'ほん',
        romaji: 'hon',
        meaning: 'sách',
        example: '本を読みます。',
        exampleVi: 'Tôi đọc sách.',
      ),
      FlashcardWord(
        word: '猫',
        hiragana: 'ねこ',
        romaji: 'neko',
        meaning: 'con mèo',
        example: '猫がいます。',
        exampleVi: 'Có một con mèo.',
      ),
    ],
  ),
];
