import 'flashcard_deck.dart';

/// In-memory practice only. Results are not persisted or sent to the server.
class FlashcardSession {
  FlashcardSession(List<FlashcardWord> words)
    : words = List.unmodifiable(words);

  final List<FlashcardWord> words;
  final Map<FlashcardWord, bool> _answers = {};
  int _index = 0;
  bool _revealed = false;

  int get answered => _index;
  int get remembered => _answers.values.where((value) => value).length;
  int get graded => _answers.length;
  List<FlashcardWord> get forgotten =>
      List.unmodifiable(words.where((word) => _answers[word] == false));
  bool get isComplete => _index >= words.length;
  bool get isRevealed => _revealed;
  FlashcardWord? get current => isComplete ? null : words[_index];
  double get progress => words.isEmpty ? 0 : _index / words.length;

  void flip() {
    if (!isComplete) _revealed = !_revealed;
  }

  void select(int index) {
    if (index < 0 || index >= words.length) return;
    _index = index;
    _revealed = false;
  }

  bool answer({required bool remembered}) {
    if (isComplete || !_revealed) return false;
    _answers[current!] = remembered;
    _index++;
    _revealed = false;
    return true;
  }
}
