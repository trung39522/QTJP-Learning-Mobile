class FlashcardWord {
  const FlashcardWord({
    this.id,
    required this.word,
    required this.hiragana,
    required this.romaji,
    required this.meaning,
    required this.example,
    required this.exampleVi,
    this.hanViet = '',
    this.partOfSpeech = '',
    this.exampleFurigana = const [],
  });

  final int? id;
  final String word;
  final String hiragana;
  final String romaji;
  final String meaning;
  final String example;
  final String exampleVi;
  final String hanViet;
  final String partOfSpeech;
  final List<Map<String, dynamic>> exampleFurigana;
}

class FlashcardDeck {
  FlashcardDeck({
    required this.id,
    required this.name,
    required this.level,
    required this.description,
    required List<FlashcardWord> words,
    this.wordCount,
    this.isSample = false,
    this.systemDeck = true,
    this.ownerUserId,
    this.category = '',
  }) : words = List.unmodifiable(words);

  final String id;
  final String name;
  final String level;
  final String description;
  final List<FlashcardWord> words;
  final int? wordCount;
  final bool isSample;
  final bool systemDeck;
  final int? ownerUserId;
  final String category;
  int get count => wordCount ?? words.length;

  FlashcardDeck withWords(List<FlashcardWord> value) => FlashcardDeck(
    id: id,
    name: name,
    level: level,
    description: description,
    words: value,
    isSample: isSample,
    systemDeck: systemDeck,
    ownerUserId: ownerUserId,
    category: category,
  );
}
